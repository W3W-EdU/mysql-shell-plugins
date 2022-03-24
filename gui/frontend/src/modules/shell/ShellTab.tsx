/*
 * Copyright (c) 2021, 2022, Oracle and/or its affiliates.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License, version 2.0,
 * as published by the Free Software Foundation.
 *
 * This program is also distributed with certain software (including
 * but not limited to OpenSSL) that is licensed under separate terms, as
 * designated in a particular file or component or in included license
 * documentation.  The authors of MySQL hereby grant you an additional
 * permission to link the program and your derivative works with the
 * separately licensed software that they have included with MySQL.
 * This program is distributed in the hope that it will be useful,  but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
 * the GNU General Public License, version 2.0, for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 */

import * as React from "react";

import { ApplicationDB } from "../../app-logic/ApplicationDB";
import {
    IColumnInfo, DialogType, IDialogRequest, MessageType, IDialogResponse, IDictionary, IServicePasswordRequest,
    DBDataType, IExecutionInfo,
} from "../../app-logic/Types";

import {
    ICommShellEvent, IShellDocumentData, IShellObjectResult, IShellResultType, IShellRowData,
    IShellSimpleResult, IShellValueResult, ShellPromptResponseType, IShellPromptValues, IShellFeedbackRequest,
    IShellColumnsMetaData,
} from "../../communication";
import {
    Component, Container, ContentAlignment, IComponentProperties, Orientation,
} from "../../components/ui";
import { IEditorPersistentState } from "../../components/ui/CodeEditor/CodeEditor";
import { ExecutionContext, IExecutionResult, ITextResultEntry, SQLExecutionContext } from "../../script-execution";
import { CodeEditorLanguageServices } from "../../script-execution/ScriptingLanguageServices";
import { convertRows, EditorLanguage, generateColumnInfo } from "../../supplement";
import { requisitions } from "../../supplement/Requisitions";
import { EventType } from "../../supplement/Dispatch";
import { settings } from "../../supplement/Settings/Settings";
import { DBType, ShellInterfaceShellSession } from "../../supplement/ShellInterface";
import { flattenObject, stripAnsiCode } from "../../utilities/helpers";
import { ShellConsole } from "./ShellConsole";
import { ShellPrompt } from "./ShellPrompt";
import { unquote } from "../../utilities/string-helpers";

export interface IShellTabPersistentState extends IShellPromptValues {
    backend: ShellInterfaceShellSession;
    state: IEditorPersistentState;

    // Informations about the connected backend (where supported).
    serverVersion: number;
    serverEdition: string;
    sqlMode: string;
}

export interface IShellTabProperties extends IComponentProperties {
    savedState: IShellTabPersistentState;

    onQuit: (id: string) => void;
}

export class ShellTab extends Component<IShellTabProperties> {

    private static aboutMessage = `Welcome to the MySQL Shell - GUI Console.

Press %modifier%+Enter to execute the current statement.

Execute \\sql to switch to SQL, \\js to Javascript and \\py to Python mode.
Execute \\help or \\? for help; \\quit to close the session.`;

    private static languageMap = new Map<EditorLanguage, string>([
        ["javascript", "\\js"],
        ["python", "\\py"],
        ["sql", "\\sql"],
        ["mysql", "\\sql"],
    ]);

    private consoleRef = React.createRef<ShellConsole>();

    // Holds the current language that was last used by the user.
    // This way we know if we need to implicitly send a language command when the user executes arbitrary execution
    // blocks (which can have different languages).
    private currentLanguage: EditorLanguage = "text";

    public componentDidMount(): void {
        this.initialSetup();

        requisitions.register("acceptPassword", this.acceptPassword);
        requisitions.register("cancelPassword", this.cancelPassword);
        requisitions.register("dialogResponse", this.handleDialogResponse);
    }

    public componentWillUnmount(): void {
        requisitions.unregister("acceptPassword", this.acceptPassword);
        requisitions.unregister("cancelPassword", this.cancelPassword);
        requisitions.unregister("dialogResponse", this.handleDialogResponse);
    }

    public componentDidUpdate(): void {
        this.initialSetup();
    }

    public render(): React.ReactNode {
        const { savedState } = this.props;

        return (
            <>
                <Container
                    id="shellEditorHost"
                    orientation={Orientation.TopDown}
                    alignment={ContentAlignment.Stretch}
                >
                    <ShellPrompt
                        id="shellPrompt"
                        values={savedState}
                        getSchemas={this.listSchemas}
                        onSelectSchema={this.activateSchema}
                    />

                    <ShellConsole
                        id="shellEditor"
                        ref={this.consoleRef}
                        editorState={savedState.state}
                        onScriptExecution={this.handleExecution}
                    />
                </Container>
            </>
        );
    }

    private initialSetup(): void {
        const { savedState } = this.props;
        const version = savedState.state.model.getVersionId();
        if (version === 1) {
            // If there was never a change in the editor so far it means that this is the first time it is shown.
            // In this case we can run our one-time initialization.
            this.consoleRef.current?.executeCommand("\\about");

            const language = settings.get("shellSession.startLanguage", "javascript").toLowerCase() as EditorLanguage;
            const languageSwitch = ShellTab.languageMap.get(language) ?? "\\js";
            this.currentLanguage = language;
            savedState.backend.execute(languageSwitch).then((event: ICommShellEvent) => {
                // Update the prompt after executing the first command. This is important
                // if the shell session was started with a dbConnectionId to connect to.
                if (event && event.data && event.eventType === EventType.FinalResponse) {
                    // Need to cast to any, as some of the result types do not have a prompt descriptor.
                    const result = event.data.result;
                    if (result && this.hasPromptDescriptor(result)) {
                        savedState.promptDescriptor = result.promptDescriptor;
                        void requisitions.execute("updateShellPrompt", result);
                    }
                }
            }).catch((event) => {
                void requisitions.execute("showError", ["Shell Language Switch Error", String(event.message)]);
            });
        }
    }

    /**
     * Handles all incoming execution requests from the editors.
     *
     * @param context The context containing the code to be executed.
     * @param params Additional named parameters.
     */
    private handleExecution = (context: ExecutionContext, params?: Array<[string, string]>): void => {
        const { savedState } = this.props;

        const command = context.code.trim();

        // First check for special commands.
        let runExecution = true;

        const parts = command.split(" ");
        if (parts.length > 0) {
            const temp = parts[0].toLowerCase();

            // If this is a language switch, store it for later comparison. For SQL, however, only when it doesn't do
            // ad hoc execution.
            switch (temp) {
                case "\\quit":
                case "\\exit":
                case "\\q":
                case "\\e": {
                    setImmediate(() => {
                        const { id, onQuit } = this.props;

                        onQuit(id ?? "");
                    });

                    return;
                }

                case "\\about": {
                    const isMac = navigator.userAgent.includes("Macintosh");
                    const content = ShellTab.aboutMessage.replace("%modifier%", isMac ? "Cmd" : "Ctrl");
                    context?.setResult({
                        type: "text",
                        requestId: "",
                        text: [{ type: MessageType.Info, index: -1, content, language: "ansi" }],
                    });

                    return;
                }

                case "\\js": {
                    this.currentLanguage = "javascript";
                    break;
                }

                case "\\py": {
                    this.currentLanguage = "python";
                    break;
                }

                case "\\sql": {
                    if (parts.length === 1) {
                        this.currentLanguage = "sql";
                    }
                    break;
                }

                default: {
                    const language = context.language === "mysql" ? "sql" : context.language;
                    if (language !== this.currentLanguage) {
                        const languageSwitch = ShellTab.languageMap.get(context.language);
                        if (languageSwitch) {
                            runExecution = false; // We do it here.
                            savedState.backend.execute(languageSwitch).then((event: ICommShellEvent) => {
                                if (event.eventType === EventType.FinalResponse) {
                                    this.currentLanguage = language;
                                    void this.processCommand(command, context, params);
                                }
                            }).catch((event) => {
                                void requisitions.execute("showError",
                                    ["Shell Language Switch Error", String(event.message)]);
                            });
                        }
                    }

                    break;
                }
            }
        }

        if (runExecution) {
            void this.processCommand(command, context, params);
        }
    };

    /**
     * Does language dependent processing before the command is actually sent to the backend.
     *
     * @param command The command to execute.
     * @param context The context for the execution and target for the results.
     * @param params Additional named parameters.
     */
    private async processCommand(command: string, context: ExecutionContext,
        params?: Array<[string, string]>): Promise<void> {
        if (!command.startsWith("\\") && context.isSQLLike) {
            const statements = (context as SQLExecutionContext).statements;

            let index = 0;
            while (true) {
                const statement = statements.shift();
                if (!statement) {
                    break;
                }
                await this.executeQuery(context as SQLExecutionContext, statement.text, index++, params);
            }
        } else {
            void this.doExecution(command, context, -1, params);
        }
    }

    /**
     * Executes a single query. The query is amended with a LIMIT clause, if the given count is > 0 (the page size)
     * and no other top level LIMIT clause already exists.
     *
     * @param context The context to send results to.
     * @param sql The query to execute.
     * @param index The index of the query being executed.
     * @param params Additional named parameters.
     *
     * @returns A promise which resolves when the query execution is finished.
     */
    private executeQuery = async (context: SQLExecutionContext, sql: string, index: number,
        params?: Array<[string, string]>): Promise<void> => {
        if (sql.trim().length === 0) {
            return;
        }

        return new Promise((resolve, reject) => {
            const services = CodeEditorLanguageServices.instance;

            void services.checkAndAddSemicolon(context, sql).then(([query]) => {
                void this.doExecution(query, context, index, params)
                    .then(() => { resolve(); })
                    .catch((reason) => { reject(reason); });
            });
        });
    };

    private doExecution(command: string, context: ExecutionContext, index: number,
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        params?: Array<[string, string]>): Promise<void> {
        const { savedState } = this.props;
        const columns: IColumnInfo[] = [];

        return new Promise((resolve, reject) => {
            savedState.backend.execute(command).then((event: ICommShellEvent) => {
                if (!event.data) {
                    return;
                }

                const { id = "" } = this.props;

                const requestId = event.data.requestId!;
                const result = event.data.result;

                const addResultData = (data: IExecutionResult): void => {
                    void context.addResultData(data).then((added) => {
                        if (added) {
                            context.updateResultDisplay();
                        }
                    });
                };

                switch (event.eventType) {
                    case EventType.ErrorResponse: {
                        // This is just here to complete the picture. Shell execute responses don't use ERROR types,
                        // but instead return error conditions in the normal OK/PENDING responses.
                        break;
                    }

                    case EventType.StartResponse: {
                        if (index < 0) {
                            // For anything but SQL.
                            context.setResult();
                        } else if (index === 0) {
                            // For the first SQL result.
                            context.setResult({
                                type: "resultSets",
                                sets: [{
                                    index,
                                    head: {
                                        requestId,
                                        sql: "",
                                    },
                                    data: {
                                        requestId,
                                        rows: [],
                                        columns: [],
                                        currentPage: 0,
                                    },
                                }],
                            });
                        } else {
                            // For any further SQL result from the same execution context.
                            context.addResultPage({
                                type: "resultSets",
                                sets: [{
                                    index,
                                    head: {
                                        requestId,
                                        sql: "",
                                    },
                                    data: {
                                        requestId,
                                        rows: [],
                                        columns: [],
                                        currentPage: 0,
                                    },
                                }],
                            });
                        }

                        break;
                    }

                    case EventType.DataResponse: {
                        if (!result) {
                            break;
                        }

                        // Shell response results can have many different fields. There's no other way but to test
                        // for each possible field to see what a response is about.
                        if (this.isShellShellDocumentData(result)) {
                            // Document data must be handled first, as that includes an info field,
                            // like the simple result.
                            if (result.hasData) {
                                const documentString = result.documents.length === 1 ? "document" : "documents";
                                const status = {
                                    type: MessageType.Info,
                                    text: `${result.documents.length} ${documentString} in set ` +
                                        `(${result.executionTime})`,
                                };

                                if (result.warningCount > 0) {
                                    status.type = MessageType.Warning;
                                    status.text += `, ${result.warningCount} ` +
                                        `${result.warningCount === 1 ? "warning" : "warnings"}`;
                                }

                                const text: ITextResultEntry[] = [{
                                    type: MessageType.Info,
                                    index,
                                    content: JSON.stringify(result.documents, undefined, "\t"),
                                    language: "json",
                                }];

                                result.warnings.forEach((warning) => {
                                    text.push({
                                        type: MessageType.Warning,
                                        index,
                                        content: `\n${warning.message}`,
                                    });
                                });

                                addResultData({
                                    type: "text",
                                    text,
                                    executionInfo: status,
                                });
                            } else {
                                // No data was returned. Use the info field for the status message then.
                                addResultData({
                                    type: "text",
                                    text: [{
                                        type: MessageType.Info,
                                        index,
                                        content: result.info,
                                        language: "ansi",
                                    }],
                                    executionInfo: { text: "" },
                                });
                            }
                        } else if (this.isShellShellColumnsMetaData(result)) {
                            const rawColumns = Object.values(result).map((value) => {
                                return {
                                    name: unquote(value.Name),
                                    type: value.Type,
                                    length: value.Length,
                                };
                            });
                            columns.push(...generateColumnInfo(
                                context.language === "mysql" ? DBType.MySQL : DBType.Sqlite, rawColumns));
                        } else if (this.isShellShellRowData(result)) {
                            // Document data must be handled first, as that includes an info field,
                            // like the simple result.
                            const rowString = result.rows.length === 1 ? "row" : "rows";
                            const status = {
                                type: MessageType.Info,
                                text: `${result.rows.length} ${rowString} in set (${result.executionTime})`,
                            };

                            if (result.warningCount > 0) {
                                status.type = MessageType.Warning;
                                status.text += `, ${result.warningCount} ` +
                                    `${result.warningCount === 1 ? "warning" : "warnings"}`;
                            }

                            // Flatten nested objects + arrays.
                            result.rows.forEach((value) => {
                                flattenObject(value as IDictionary);
                            });

                            // XXX: temporary workaround: create generic columns from data.
                            // Column info should actually be return in the columns meta data response above.
                            if (columns.length === 0 && result.rows.length > 0) {
                                const row = result.rows[0] as object;
                                Object.keys(row).forEach((value) => {
                                    columns.push({
                                        name: value,
                                        dataType: {
                                            type: DBDataType.String,
                                        },
                                    });
                                });
                            }

                            const rows = convertRows(columns, result.rows);

                            void ApplicationDB.db.add("shellModuleResultData", {
                                tabId: id,
                                requestId,
                                rows,
                                columns,
                                executionInfo: status,
                                index,
                            });

                            if (index === -1) {
                                // An index of -1 indicates that we are handling non-SQL mode results and have not
                                // set an initial result record in the execution context. Have to do that now.
                                index = -2;
                                context.setResult({
                                    type: "resultSets",
                                    sets: [{
                                        index,
                                        head: {
                                            requestId,
                                            sql: "",
                                        },
                                        data: {
                                            requestId,
                                            rows,
                                            columns,
                                            currentPage: 0,
                                            executionInfo: status,
                                        },
                                    }],
                                });
                            } else {
                                addResultData({
                                    type: "resultSetRows",
                                    requestId,
                                    rows,
                                    columns,
                                    currentPage: 0,
                                    executionInfo: status,
                                });
                            }

                        } else if (this.isShellShellData(result)) {
                            // Unspecified shell data (no documents, no rows). Just print the info as status, for now.
                            addResultData({
                                type: "text",
                                requestId: event.data.requestId,
                                text: [{
                                    type: MessageType.Info,
                                    index,
                                    content: result.info,
                                    language: "ansi",
                                }],
                                executionInfo: { text: "" },
                            });
                        } else if (this.isShellObjectListResult(result)) {
                            let text = "[\n";
                            result.forEach((value) => {
                                text += "\t<" + value.class;
                                if (value.name) {
                                    text += ":" + value.name;
                                }
                                text += ">\n";
                            });
                            text += "]";
                            addResultData({
                                type: "text",
                                requestId: event.data.requestId,
                                text: [{
                                    type: MessageType.Info,
                                    index,
                                    content: text,
                                    language: "xml",
                                }],
                            });
                        } else if (this.isShellSimpleResult(result)) {
                            if (result.error) {
                                // Errors can be a string or an object with a string.
                                const text = typeof result.error === "string" ? result.error : result.error.message;
                                addResultData({
                                    type: "text",
                                    requestId: event.data.requestId,
                                    text: [{
                                        type: MessageType.Error,
                                        index,
                                        content: text,
                                        language: "ansi",
                                    }],
                                    executionInfo: { type: MessageType.Error, text: "" },
                                });
                            } else if (result.warning) {
                                // Errors can be a string or an object with a string.
                                addResultData({
                                    type: "text",
                                    requestId: event.data.requestId,
                                    text: [{
                                        type: MessageType.Info,
                                        index,
                                        content: result.warning,
                                        language: "ansi",
                                    }],
                                    executionInfo: { type: MessageType.Warning, text: "" },
                                });
                            } else {
                                const content = (result.info ?? result.note ?? result.status)!;
                                addResultData({
                                    type: "text",
                                    requestId: event.data.requestId,
                                    text: [{
                                        type: MessageType.Info,
                                        index,
                                        content,
                                        language: "ansi",
                                    }],
                                });
                            }
                        } else if (this.isShellValueResult(result)) {
                            addResultData({
                                type: "text",
                                requestId: event.data.requestId,
                                text: [{
                                    type: MessageType.Info,
                                    index,
                                    content: String(result.value),
                                    language: "ansi",
                                }],
                            });
                        } else if (this.isShellPromptResult(result)) {
                            if (result.password) {
                                addResultData({
                                    type: "text",
                                    requestId,
                                    text: [{
                                        type: MessageType.Interactive,
                                        index,
                                        content: result.password,
                                        language: "ansi",
                                    }],
                                });

                                // Extract the service id (and from that the user name) from the password prompt.
                                const parts = result.password.split("'");
                                if (parts.length >= 3) {
                                    const parts2 = parts[1].split("@");
                                    const passwordRequest: IServicePasswordRequest = {
                                        requestId,
                                        caption: "Open MySQL Connection in Shell Session",
                                        service: parts[1],
                                        user: parts2[0],
                                    };
                                    void requisitions.execute("requestPassword", passwordRequest);
                                } else {
                                    const passwordRequest: IServicePasswordRequest = {
                                        requestId,
                                        caption: "MySQL Shell Password Request",
                                        description: result.password,
                                    };
                                    void requisitions.execute("requestPassword", passwordRequest);
                                }

                            } else if (result.prompt) {
                                // Any other input requested from the user.
                                const promptRequest: IDialogRequest = {
                                    type: DialogType.Prompt,
                                    id: "shellPromptDialog",
                                    values: {
                                        prompt: stripAnsiCode(result.prompt),
                                    },
                                    data: {
                                        requestId,
                                    },
                                };
                                void requisitions.execute("showDialog", promptRequest);
                            }
                        } else if (this.isShellObjectResult(result)) {
                            let text = "<" + result.class;
                            if (result.name) {
                                text += ":" + result.name;
                            }
                            text += ">";
                            addResultData({
                                type: "text",
                                requestId: event.data.requestId,
                                text: [{
                                    type: MessageType.Info,
                                    index,
                                    content: text,
                                    language: "xml",
                                }],
                            });
                        } else {
                            // If no specialized result then print as is.
                            const executionInfo: IExecutionInfo = {
                                text: JSON.stringify(event.data.requestState, undefined, "\t"),
                            };
                            addResultData({
                                type: "text",
                                text: [],
                                executionInfo,
                            });
                        }

                        break;
                    }

                    case EventType.FinalResponse: {
                        // Need to cast to any, as some of the result types do not have a prompt descriptor.
                        if (result && this.hasPromptDescriptor(result)) {
                            savedState.promptDescriptor = result.promptDescriptor;
                            void requisitions.execute("updateShellPrompt", result);
                        }

                        // Note: we don't send a final result display update call from here. Currently the shell
                        //       sends all relevant data in data responses. The final response doesn't really add
                        //       anything, so we do such updates in the data responses instead (and get live resizes).
                        resolve();

                        break;
                    }

                    default: {
                        break;
                    }
                }

            }).catch((event) => {
                const message = event.message ? String(event.message) : "No further information";
                void requisitions.execute("showError", ["Shell Execution Error", message]);
                reject(message);
            });

        });
    }

    private handleDialogResponse = (response: IDialogResponse): Promise<boolean> => {
        return new Promise((resolve) => {
            const { savedState } = this.props;

            if (response.data) {
                if (response.accepted) {
                    savedState.backend.sendReply(response.data.requestId as string, ShellPromptResponseType.Ok,
                        response.values?.input as string);
                } else {
                    savedState.backend.sendReply(response.data.requestId as string, ShellPromptResponseType.Cancel, "");
                }

                resolve(true);
            }

            resolve(false);
        });
    };

    private acceptPassword = (data: { request: IServicePasswordRequest; password: string }): Promise<boolean> => {
        return new Promise((resolve) => {
            const { savedState } = this.props;

            savedState.backend.sendReply(data.request.requestId, ShellPromptResponseType.Ok, data.password)
                .then(() => { resolve(true); })
                .catch(() => { resolve(false); });
        });
    };

    private cancelPassword = (request: IServicePasswordRequest): Promise<boolean> => {
        return new Promise((resolve) => {
            const { savedState } = this.props;

            savedState.backend.sendReply(request.requestId, ShellPromptResponseType.Cancel, "")
                .then(() => { resolve(true); })
                .catch(() => { resolve(false); });

        });
    };

    private listSchemas = (): Promise<string[]> => {
        return new Promise((resolve) => {
            // TODO: get the schema list from the backend.
            resolve(["mysql", "sakila"]);
        });
    };

    private activateSchema = (schemaName: string): void => {
        this.consoleRef.current?.executeCommand(`\\u ${schemaName}`);
    };

    // Different type guards below, to keep various shell results apart.

    private isShellPromptResult(response: IShellResultType): response is IShellFeedbackRequest {
        const candidate = response as IShellFeedbackRequest;

        return candidate.prompt !== undefined || candidate.password !== undefined;
    }

    private isShellObjectListResult(response: IShellResultType): response is IShellObjectResult[] {
        return Array.isArray(response);
    }

    private isShellObjectResult(response: IShellResultType): response is IShellObjectResult {
        return (response as IShellObjectResult).class !== undefined;
    }

    private isShellValueResult(response: IShellResultType): response is IShellValueResult {
        return (response as IShellValueResult).value !== undefined;
    }

    private isShellSimpleResult(response: IShellResultType): response is IShellSimpleResult {
        const candidate = response as IShellSimpleResult;

        return (candidate.error !== undefined || candidate.info !== undefined || candidate.note !== undefined
            || candidate.status !== undefined || candidate.warning !== undefined)
            && Object.keys(candidate).length === 1;
    }

    private isShellShellDocumentData(response: IShellResultType): response is IShellDocumentData {
        return (response as IShellDocumentData).documents !== undefined;
    }

    private isShellShellColumnsMetaData(response: IShellResultType): response is IShellColumnsMetaData {
        return (response as IShellColumnsMetaData)["Field 1"] !== undefined;
    }

    private isShellShellRowData(response: IShellResultType): response is IShellRowData {
        return (response as IShellRowData).rows !== undefined;
    }

    private isShellShellData(response: IShellResultType): response is IShellDocumentData {
        return (response as IShellDocumentData).hasData !== undefined;
    }

    private hasPromptDescriptor(response: IShellResultType): response is IShellPromptValues {
        return (response as IShellPromptValues).promptDescriptor !== undefined;
    }

}
