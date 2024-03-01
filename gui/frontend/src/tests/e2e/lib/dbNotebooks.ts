/*
 * Copyright (c) 2021, 2024, Oracle and/or its affiliates.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License, version 2.0,
 * as published by the Free Software Foundation.
 *
 * This program is designed to work with certain software (including
 * but not limited to OpenSSL) that is licensed under separate terms, as
 * designated in a particular file or component or in included license
 * documentation.  The authors of MySQL hereby grant you an additional
 * permission to link the program and your derivative works with the
 * separately licensed software that they have included with
 * the program or referenced in the documentation.
 *
 * This program is distributed in the hope that it will be useful,  but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
 * the GNU General Public License, version 2.0, for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 */

import { until, WebElement, Key, error } from "selenium-webdriver";
import { explicitWait, IDBConnection } from "./misc.js";
import * as locator from "../lib/locators.js";
import * as constants from "../lib/constants.js";
import { driver } from "../lib/driver.js";

export const execFullBlockSql = "Execute the selection or everything in the current block and create a new block";
export const execFullBlockJs = "Execute everything in the current block and create a new block";
export const execCaret = "Execute the statement at the caret position";
export const execFullScript = "Execute full script";
export const find = "Find";
export const rollback = "Rollback DB changes";
export const commit = "Commit DB changes";
export const autoCommit = "Auto commit DB changes";
export const saveNotebook = "Save this Notebook";

export class DBNotebooks {

    /**
     * Selects the database type on the Database Connection Configuration dialog
     * @param value database type
     * @returns Promise resolving when the select is made
     */
    public static selectDBType = async (value: string): Promise<void> => {
        await driver.findElement(locator.databaseConnectionConfiguration.databaseType.exists).click();
        const dropDownList = await driver.findElement(locator.databaseConnectionConfiguration.databaseType.list);
        const els = await dropDownList.findElements(locator.htmlTag.div);
        if (els.length > 0) {
            await dropDownList.findElement(locator.searchById(value)).click();
        }
    };

    /**
     * Selects the protocol on the Database Connection Configuration dialog
     * @param value protocol
     * @returns Promise resolving when the select is made
     */
    public static setProtocol = async (value: string): Promise<void> => {
        await driver.findElement(locator.databaseConnectionConfiguration.mysql.basic.protocol.exists).click();
        const dropDownList = await driver
            .findElement(locator.databaseConnectionConfiguration.mysql.basic.protocol.list);
        await dropDownList.findElement(locator.searchById(value)).click();
    };

    /**
     * Selects the SSL Mode on the Database Connection Configuration dialog
     * @param value SSL Mode
     * @returns Promise resolving when the select is made
     */
    public static setSSLMode = async (value: string): Promise<void> => {
        await driver.findElement(locator.databaseConnectionConfiguration.mysql.ssl.mode).click();
        const dropDownList = await driver
            .findElement(locator.databaseConnectionConfiguration.mysql.ssl.modeList.exists);
        await dropDownList.findElement(locator.searchById(value)).click();
    };

    /**
     * Creates a new database connection, from the DB Editor main page.
     * It verifies that the Connection dialog is closed, at the end.
     * @param dbConfig SSL Mode
     * @returns Promise resolving with the connection created
     */
    public static createDBconnection = async (dbConfig: IDBConnection):
        Promise<WebElement | undefined> => {
        const ctx = await driver.wait(until.elementLocated(locator.dbConnections.browser),
            explicitWait, "DB Connection Overview page was not loaded");

        await driver.wait(async () => {
            const isDialogVisible = (await driver.findElements(locator.databaseConnectionConfiguration.exists))
                .length > 0;
            if (isDialogVisible) {
                return true;
            } else {
                try {
                    await ctx.findElement(locator.dbConnections.newConnection).click();
                } catch (e) {
                    if (!(e instanceof error.ElementClickInterceptedError)) {
                        throw e;
                    }
                }

                return false;
            }
        }, explicitWait, "Connection dialog was not displayed");

        const newConDialog = await driver.findElement(locator.databaseConnectionConfiguration.exists);

        await driver.wait(async () => {
            await newConDialog.findElement(locator.databaseConnectionConfiguration.caption).clear();

            return !(await driver.executeScript("return document.querySelector('#caption').value"));
        }, 3000, "caption was not cleared in time");
        await newConDialog.findElement(locator.databaseConnectionConfiguration.caption).sendKeys(dbConfig.caption);
        await newConDialog.findElement(locator.databaseConnectionConfiguration.description).clear();
        await newConDialog
            .findElement(locator.databaseConnectionConfiguration.description)
            .sendKeys(dbConfig.description);
        await newConDialog.findElement(locator.databaseConnectionConfiguration.mysql.basic.hostname).clear();
        await newConDialog.findElement(locator.databaseConnectionConfiguration.mysql.basic.hostname)
            .sendKeys(String(dbConfig.hostname));
        await DBNotebooks.setProtocol(dbConfig.protocol);
        await driver.findElement(locator.databaseConnectionConfiguration.mysql.basic.port).clear();
        await driver.findElement(locator.databaseConnectionConfiguration.mysql.basic.port)
            .sendKeys(String(dbConfig.port));
        await newConDialog.findElement(locator.databaseConnectionConfiguration.mysql.basic.username)
            .sendKeys(String(dbConfig.username));
        await newConDialog
            .findElement(locator.databaseConnectionConfiguration.mysql.basic.schema)
            .sendKeys(String(dbConfig.schema));

        if (dbConfig.dbType) {
            await DBNotebooks.selectDBType(dbConfig.dbType);
        }

        if (dbConfig.sslMode) {
            await newConDialog.findElement(locator.databaseConnectionConfiguration.sslTab).click();
            await newConDialog.findElement(locator.databaseConnectionConfiguration.mysql.ssl.mode).click();
            const dropDownList = await driver
                .findElement(locator.databaseConnectionConfiguration.mysql.ssl.modeList.exists);
            await dropDownList.findElement(locator.searchById(dbConfig.sslMode)).click();
            expect(await newConDialog
                .findElement(locator.databaseConnectionConfiguration.mysql.ssl.modeLabel).getText())
                .toBe(dbConfig.sslMode);

            const certsPath = process.env.SSLCERTSPATH as string;
            const paths = await newConDialog.findElements(locator.databaseConnectionConfiguration.mysql.ssl.inputs);
            await paths[0].sendKeys(`${certsPath}/ca-cert.pem`);
            await paths[1].sendKeys(`${certsPath}/client-cert.pem`);
            await paths[2].sendKeys(`${certsPath}/client-key.pem`);
        }

        const okBtn = await driver.findElement(locator.databaseConnectionConfiguration.ok);
        await driver.executeScript("arguments[0].scrollIntoView(true)", okBtn);
        await okBtn.click();
        expect((await driver.findElements(locator.databaseConnectionConfiguration.exists)).length).toBe(0);

        return driver.wait(async () => {
            const connections = await driver.findElements(locator.dbConnections.connections.item);
            for (const connection of connections) {
                const el = await connection.findElement(locator.dbConnections.connections.caption);
                if ((await el.getAttribute("innerHTML")).includes(dbConfig.caption)) {
                    return connection;
                }
            }
        }, explicitWait, `'${dbConfig.caption}' was not created`);
    };

    /**
     * Returns the WebElement that represents the DB Connection, on the DB Connection main page
     * Throws an exception if not found.
     * @param name Connection caption
     * @returns @returns Promise resolving with the DB Connection
     */
    public static getConnection = async (name: string): Promise<WebElement | undefined> => {

        return driver.wait(async () => {
            const connections = await driver.findElements(locator.dbConnections.connections.item);
            for (const connection of connections) {
                const el = await connection.findElement(locator.dbConnections.connections.caption);
                if ((await el.getAttribute("innerHTML")).includes(name)) {
                    return connection;
                }
            }
        }, 1500, "Could not find any connection");

    };

    public static clickConnectionItem = async (conn: WebElement, item: string): Promise<void> => {
        const moreActions = await conn.findElement(locator.dbConnections.connections.actions.moreActions);
        const moreActionsRect = await moreActions.getRect();
        await driver.actions().move({
            x: parseInt(`${moreActionsRect.x}`, 10),
            y: parseInt(`${moreActionsRect.y}`, 10),
        }).perform();
        switch (item) {
            case "notebook": {
                await conn.findElement(locator.dbConnections.connections.actions.newNotebook).click();
                break;
            }
            case "script": {
                await conn.findElement(locator.dbConnections.connections.actions.newScript).click();
                break;
            }
            case "edit": {
                await moreActions.click();
                await driver.wait(until.elementLocated(locator.dbConnections.connections.actions.edit),
                    explicitWait, "Edit button not found").click();
                break;
            }
            case "duplicate": {
                await moreActions.click();
                await driver.wait(until.elementLocated(locator.dbConnections.connections.actions.duplicate),
                    explicitWait, "Duplicate button not found").click();
                break;
            }
            case "remove": {
                await moreActions.click();
                await driver.wait(until.elementLocated(locator.dbConnections.connections.actions.remove),
                    explicitWait, "Remove button not found").click();
                break;
            }
            default: {
                break;
            }
        }
    };

    /**
     * Returns the autocomplete context item list
     * @returns A promise resolving when the list is fulfilled
     */
    public static getAutoCompleteMenuItems = async (): Promise<string[]> => {
        const els = [];
        let items = await driver.wait(until.elementsLocated(locator.notebook.codeEditor.autoCompleteItems),
            explicitWait, "Auto complete items were not displayed");

        for (const item of items) {
            els.push(await item.getText());
        }

        await driver.actions().sendKeys(Key.ARROW_UP).perform();

        items = await driver.wait(until.elementsLocated(locator.notebook.codeEditor.autoCompleteItems),
            explicitWait, "Auto complete items were not displayed");

        for (const item of items) {
            els.push(await item.getText());
        }

        return [...new Set(els)];
    };

    /**
     * Gets the line number where the mouse cursor is
     * @returns A promise resolving with the line number
     */
    public static getMouseCursorLine = async (): Promise<number | undefined> => {
        const lines = await driver.findElements(locator.notebook.codeEditor.editor.cursorLine);
        for (let i = 0; i <= lines.length - 1; i++) {
            const curLine = await lines[i].findElements(locator.notebook.codeEditor.editor.currentLine);
            if (curLine.length > 0) {
                return i;
            }
        }
    };

    /**
     * Gets the line number where a word is found
     * @param wordRef The word
     * @returns A promise resolving with the line number
     */
    public static getLineFromWord = async (wordRef: string): Promise<number | undefined> => {
        let line: number | undefined;
        await driver.wait(async () => {
            try {
                const lines = await driver.findElements(locator.notebook.codeEditor.editor.editorPrompt);
                for (let i = 0; i <= lines.length - 1; i++) {
                    const match = (await lines[i].getAttribute("innerHTML")).match(/(?<=">)(.*?)(?=<\/span>)/gm);
                    if (match !== null) {
                        const cmdFromEditor = match.join("").replace(/&nbsp;/g, " ");
                        if (cmdFromEditor === wordRef) {
                            line = i;

                            return true;
                        }
                    }
                }
            } catch (e) {
                if (!(e instanceof error.StaleElementReferenceError)) {
                    throw e;
                }
            }
        }, explicitWait, "The lines were always stale");

        if (line === undefined) {
            throw new Error(`Could not find the line of word ${wordRef}`);
        } else {
            return line;
        }
    };

    /**
     * Sets the mouse cursor at the editor line where the specified word is
     * @param word The word or command
     * @returns A promise resolving when the mouse cursor is placed at the desired spot
     */
    public static setMouseCursorAt = async (word: string): Promise<void> => {
        const mouseCursorIs = await DBNotebooks.getMouseCursorLine();
        const mouseCursorShouldBe = await DBNotebooks.getLineFromWord(word) ?? 0;
        const taps = mouseCursorShouldBe - mouseCursorIs!;
        const textArea = await driver.findElement(locator.notebook.codeEditor.textArea);
        if (taps > 0) {
            for (let i = 0; i < taps; i++) {
                await textArea.sendKeys(Key.ARROW_DOWN);
                await driver.sleep(300);
            }
        } else if (taps < 0) {
            for (let i = 0; i < Math.abs(taps); i++) {
                await textArea.sendKeys(Key.ARROW_UP);
                await driver.sleep(300);
            }
        }
    };

    /**
     * Sets a new line on the notebook editor
     * @returns A promise resolving when the new line is set
     */
    public static setNewLineOnEditor = async (): Promise<void> => {
        let newLineNumber: number;
        const getLastLineNumber = async (): Promise<number> => {
            await driver.wait(async () => {
                try {
                    const lineNumbers = await driver.findElements(locator.notebook.codeEditor.editor.lineNumber);
                    if (lineNumbers.length === 0) {
                        return 0;
                    } else {
                        const numbers = await Promise.all(
                            lineNumbers.map(async (lineNumber: WebElement) => {
                                return parseInt(await lineNumber.getAttribute("innerHTML"), 10);
                            }));

                        newLineNumber = Math.max(...numbers);

                        return true;
                    }
                } catch (e) {
                    if (!(e instanceof error.StaleElementReferenceError)) {
                        throw e;
                    }
                }
            }, constants.wait5seconds, "Line numbers were stale");

            return newLineNumber;
        };

        await driver.wait(async () => {
            const lastLineNumber = await getLastLineNumber();
            const textArea = await driver.findElement(locator.notebook.codeEditor.textArea);
            await textArea.sendKeys(Key.ESCAPE); // close the suggestions menu if exists
            await textArea.sendKeys(Key.ENTER);

            return (await getLastLineNumber()) > lastLineNumber;
        }, constants.wait5seconds, "Could not set a new line on the editor");
    };

    /**
     * Gets the last text on the last prompt/editor line
     * @returns A promise resolving with the text
     */
    public static getPromptLastTextLine = async (): Promise<String> => {
        const context = await driver.findElement(locator.notebook.codeEditor.editor.exists);
        let sentence = "";
        await driver.wait(async () => {
            try {
                const codeLineWords = await context.findElements(locator.notebook.codeEditor.editor.wordInSentence);
                if (codeLineWords.length > 0) {
                    for (const word of codeLineWords) {
                        sentence += (await word.getText()).replace("&nbsp;", " ");
                    }

                    return true;
                }
            } catch (e) {
                if (!(e instanceof error.StaleElementReferenceError)) {
                    throw e;
                }
            }
        }, constants.wait5seconds, "Could not get the text from last prompt line");

        return sentence;
    };

    /**
     * Gets a toolbar button
     * @param button The button name
     * @returns A promise resolving with the button
     */
    public static getToolbarButton = async (button: string): Promise<WebElement | undefined> => {
        const toolbar = await driver.wait(until.elementLocated(locator.notebook.toolbar.exists),
            constants.wait5seconds, "Toolbar was not found");
        const buttons = await toolbar.findElements(locator.notebook.toolbar.button.exists);
        for (const btn of buttons) {
            if ((await btn.getAttribute("data-tooltip")) === button) {
                return btn;
            }
        }

        throw new Error(`Could not find '${button}' button`);
    };

    /**
     * Verifies if a toolbar button exists
     * @param button The button
     * @returns A promise resolving with true if the button exists, false otherwise
     */
    public static existsToolbarButton = async (button: string): Promise<boolean> => {
        const toolbar = await driver.wait(until.elementLocated(locator.notebook.toolbar.exists),
            constants.wait5seconds, "Toolbar was not found");
        const buttons = await toolbar.findElements(locator.notebook.toolbar.button.exists);
        for (const btn of buttons) {
            if ((await btn.getAttribute("data-tooltip")) === button) {
                return true;
            }
        }

        return false;
    };

    /**
     * Toggles the find in selection on the find widget
     * @param flag True to enable, false otherwise
     * @returns A promise resolving when button is clicked
     */
    public static widgetFindInSelection = async (flag: boolean): Promise<void> => {
        const findWidget = await driver.wait(until.elementLocated(locator.findWidget.exists), constants.wait5seconds);
        const actions = await findWidget.findElements(locator.findWidget.actions);
        for (const action of actions) {
            if ((await action.getAttribute("title")).includes("Find in selection")) {
                const checked = await action.getAttribute("aria-checked");
                if (checked === "true") {
                    if (!flag) {
                        await action.click();
                    }
                } else {
                    if (flag) {
                        await action.click();
                    }
                }

                return;
            }
        }
    };

    /**
     * Expands or collapses the find and replace on the find widget
     * @param expand True to expand, false to collapse
     * @returns A promise resolving when replacer is expanded or collapsed
     */
    public static widgetExpandFinderReplace = async (expand: boolean): Promise<void> => {
        const findWidget = await driver.wait(until.elementLocated(locator.findWidget.exists), constants.wait5seconds);
        const toggleReplace = await findWidget.findElement(locator.findWidget.toggleReplace);
        const isExpanded = (await findWidget.findElements(locator.findWidget.toggleReplaceExpanded)).length > 0;
        if (expand) {
            if (!isExpanded) {
                await toggleReplace.click();
            }
        } else {
            if (isExpanded) {
                await toggleReplace.click();
            }
        }
    };

    /**
     * Gets the replacer buttons by their name (Replace, Replace All)
     * @param button The button name
     * @returns A promise resolving when button is returned
     */
    public static widgetGetReplacerButton = async (button: string):
        Promise<WebElement | undefined> => {
        const findWidget = await driver.wait(until.elementLocated(locator.findWidget.exists), constants.wait5seconds);
        const replaceActions = await findWidget.findElements(locator.findWidget.replacerActions);
        for (const action of replaceActions) {
            if ((await action.getAttribute("title")).indexOf(button) !== -1) {
                return action;
            }
        }
    };

    /**
     * Closes the widget finder
     * @returns A promise resolving when finder is closed
     */
    public static widgetCloseFinder = async (): Promise<void> => {
        await driver.wait(async () => {
            const findWidget = await driver.findElements(locator.findWidget.exists);
            if (findWidget.length > 0) {
                const closeButton = await findWidget[0].findElement(locator.findWidget.close);
                await driver.executeScript("arguments[0].click()", closeButton);
                const widget = await driver.findElement(locator.findWidget.exists);

                return (await widget.getAttribute("class")).includes("visible") === false;
            } else {
                return true;
            }
        }, constants.wait5seconds, "The finder widget was not closed");
    };

    /**
     * Verifies if a word exists on the notebook
     * @param word The word
     * @returns A promise resolving with true if the word is found, false otherwise
     */
    public static existsOnNotebook = async (word: string): Promise<boolean> => {
        const commands: string[] = [];
        await driver.wait(async () => {
            try {
                const notebookCommands = await driver.wait(
                    until.elementsLocated(locator.notebook.codeEditor.editor.editorLine),
                    constants.wait5seconds, "No lines were found");
                for (const cmd of notebookCommands) {
                    const spans = await cmd.findElements(locator.htmlTag.span);
                    let sentence = "";
                    for (const span of spans) {
                        sentence += (await span.getText()).replace("&nbsp;", " ");
                    }
                    commands.push(sentence);
                }

                return true;
            } catch (e) {
                if (!(e instanceof error.StaleElementReferenceError)) {
                    throw e;
                }
            }
        }, constants.wait5seconds, `${word} does not exist on the notebook`);

        return commands.toString().match(new RegExp(word)) !== null;
    };
}
