/*
 * Copyright (c) 2022, 2024 Oracle and/or its affiliates.
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

import { join } from "path";
import fs from "fs/promises";
import {
    BottomBarPanel, Condition, TreeItem,
    until, WebElement, Workbench as extWorkbench, ActivityBar, CustomTreeItem,
} from "vscode-extension-tester";
import { expect } from "chai";
import clipboard from "clipboardy";
import { driver, Misc } from "../lib/Misc";
import { DatabaseConnectionDialog } from "../lib/WebViews/Dialogs/DatabaseConnectionDialog";
import { E2ENotebook } from "../lib/WebViews/E2ENotebook";
import { E2EAccordionSection } from "../lib/SideBar/E2EAccordionSection";
import { Os } from "../lib/Os";
import { Workbench } from "../lib/Workbench";
import { DialogHelper } from "../lib/WebViews/Dialogs/DialogHelper";
import { DatabaseConnectionOverview } from "../lib/WebViews/DatabaseConnectionOverview";
import * as constants from "../lib/constants";
import * as interfaces from "../lib/interfaces";
import * as locator from "../lib/locators";
import * as errors from "../lib/errors";
import { E2EShellConsole } from "../lib/WebViews/E2EShellConsole";
import { Script } from "../lib/WebViews/Script";
import { Toolbar } from "../lib/WebViews/Toolbar";
import { TestQueue } from "../lib/TestQueue";
import { LakeHouseNavigator } from "../lib/WebViews/lakehouseNavigator/lakeHouseNavigator";
import { E2EServerStatus } from "../lib/WebViews/E2EServerStatus";
import { E2EClientConnections } from "../lib/WebViews/E2EClientConnections";
import { E2EPerformanceDashboard } from "../lib/WebViews/E2EPerformanceDashboard";

describe("DATABASE CONNECTIONS", () => {

    if (!process.env.DBHOSTNAME) {
        throw new Error("Please define the environment variable DBHOSTNAME");
    }
    if (!process.env.DBUSERNAME) {
        throw new Error("Please define the environment variable DBUSERNAME");
    }
    if (!process.env.DBPASSWORD) {
        throw new Error("Please define the environment variable DBPASSWORD");
    }
    if (!process.env.DBSHELLUSERNAME) {
        throw new Error("Please define the environment variable DBSHELLUSERNAME");
    }
    if (!process.env.DBSHELLPASSWORD) {
        throw new Error("Please define the environment variable DBSHELLPASSWORD");
    }
    if (!process.env.DBPORT) {
        throw new Error("Please define the environment variable DBPORT");
    }
    if (!process.env.SSL_ROOT_FOLDER) {
        throw new Error("Please define the environment variable SSL_ROOT_FOLDER");
    }
    if (!process.env.MYSQLSH_OCI_CONFIG_FILE) {
        throw new Error("Please define the environment variable MYSQLSH_OCI_CONFIG_FILE");
    }

    const globalConn: interfaces.IDBConnection = {
        dbType: "MySQL",
        caption: `e2eGlobalDBConnection`,
        description: "Local connection",
        basic: {
            hostname: String(process.env.DBHOSTNAME),
            username: String(process.env.DBUSERNAME),
            port: Number(process.env.DBPORT),
            schema: "sakila",
            password: String(process.env.DBPASSWORD),
        },
    };

    const dbTreeSection = new E2EAccordionSection(constants.dbTreeSection);

    before(async function () {

        await Misc.loadDriver();
        try {
            await driver.wait(Workbench.untilExtensionIsReady(), constants.wait2minutes);

            if (process.env.PARALLEL) {
                await driver.wait(Misc.untilSchemaExists(constants.restServiceMetadataSchema), constants.wait2minutes);
            }

            const activityBare = new ActivityBar();
            await (await activityBare.getViewControl(constants.extensionName))?.openView();
            await Workbench.dismissNotifications();
            await Workbench.toggleBottomBar(false);
            await dbTreeSection.createDatabaseConnection(globalConn);
            await driver.wait(dbTreeSection.tree.untilExists(globalConn.caption), constants.wait5seconds);
            await Workbench.closeAllEditors();
            await new BottomBarPanel().toggle(false);
            await dbTreeSection.focus();

        } catch (e) {
            await Misc.processFailure(this);
            await Os.prepareExtensionLogsForExport(process.env.TEST_SUITE);
            throw e;
        }

    });

    after(async function () {

        try {
            await Os.prepareExtensionLogsForExport(process.env.TEST_SUITE);
            Misc.removeDatabaseConnections();
        } catch (e) {
            await Misc.processFailure(this);
            throw e;
        }

    });

    describe("Toolbar", () => {

        let treeConn: TreeItem;

        afterEach(async function () {
            if (this.currentTest.state === "failed") {
                await Misc.processFailure(this);
            }
        });

        it("Reload the connection list", async () => {

            await driver.wait(dbTreeSection.tree.untilExists(globalConn.caption), constants.wait5seconds);

        });

        it("Collapse All", async () => {

            treeConn = await dbTreeSection.tree.getElement(globalConn.caption);
            await dbTreeSection.tree.expandDatabaseConnection(treeConn,
                (globalConn.basic as interfaces.IConnBasicMySQL).password);
            const treeGlobalSchema = await dbTreeSection.tree
                .getElement((globalConn.basic as interfaces.IConnBasicMySQL).schema);
            await treeGlobalSchema.expand();
            const treeGlobalSchemaTables = await dbTreeSection.tree.getElement("Tables");
            await treeGlobalSchemaTables.expand();
            const treeGlobalSchemaViews = await dbTreeSection.tree.getElement("Views");
            await treeGlobalSchemaViews.expand();
            const treeDBSection = await dbTreeSection.getWebElement();
            await dbTreeSection.clickToolbarButton(constants.collapseAll);
            let visibleItems: CustomTreeItem[];
            await driver.wait(async () => {
                visibleItems = await treeDBSection.getVisibleItems();
                if (visibleItems.length > 0) {
                    for (const item of visibleItems) {
                        if (await item.getAttribute("aria-level") !== "1") {
                            return false;
                        }
                    }

                    return true;
                }
            }, constants.wait5seconds, "The tree is not fully collapsed");
        });

        it("Restart internal MySQL Shell process", async () => {

            await fs.truncate(Os.getMysqlshLog());
            await dbTreeSection.restartShell();

            try {
                await driver.wait(async () => {
                    const text = await fs.readFile(Os.getMysqlshLog());
                    if (text.includes("Registering session...")) {
                        return true;
                    }
                }, constants.wait20seconds, "Restarting the internal MySQL Shell server went wrong");
            } finally {
                console.log("<<<<MySQLSH Logs>>>>");
                await Os.writeMySQLshLogs();
            }

        });

        it("Relaunch Welcome Wizard", async () => {

            await Workbench.closeAllEditors();
            await dbTreeSection.selectMoreActionsItem(constants.relaunchWelcomeWizard);
            await driver.wait(Workbench.untilTabIsOpened(constants.welcomeTab), constants.wait5seconds);
            const active = await Workbench.getActiveTab();
            let error = `The active tab should be ${constants.welcomeTab}`;
            error += `, but found ${await active.getTitle()}`;
            expect(await active.getTitle(), error).equals(constants.welcomeTab);
            await driver.wait(until.ableToSwitchToFrame(0), constants.wait5seconds, "Not able to switch to frame 0");
            await driver.wait(until.ableToSwitchToFrame(
                locator.iframe.isActive), constants.wait5seconds, "Not able to switch to frame 2");
            const text = await driver.findElement(locator.welcomeWizard.title).getText();
            expect(text, `The Welcome wizard title should be ${constants.welcome}, but found ${text}`)
                .equals(constants.welcome);
            expect(await driver.findElement(locator.welcomeWizard.nextButton),
                `Next button does not exist on the welcome wizard`).to.exist;

        });

        it("Reset MySQL Shell for VS Code Extension", async () => {

            await Workbench.closeAllEditors();
            await dbTreeSection.selectMoreActionsItem(constants.resetExtension);
            let notification = "This will completely reset the MySQL Shell for VS Code extension by ";
            notification += "deleting the web certificate and user settings directory.";
            const ntf = await Workbench.getNotification(notification, false);
            await Workbench.clickOnNotificationButton(ntf, constants.cancel);

        });
    });

    describe("DB Connection Overview", () => {

        const openEditorsSection = new E2EAccordionSection(constants.openEditorsTreeSection);
        const dbConnectionOverview = new DatabaseConnectionOverview();
        let existsInQueue = false;

        before(async function () {

            try {
                await new BottomBarPanel().toggle(false);
                await Os.deleteCredentials();
                await openEditorsSection.focus();
                await (await openEditorsSection.tree.getElement(constants.dbConnectionsLabel)).click();
                await Misc.switchToFrame();
                await driver.wait(until.elementLocated(locator.dbConnectionOverview.exists),
                    constants.wait10seconds, "DB Connection Overview page was not displayed");
                const closeHeaderButton = await driver.findElements(locator.dbConnectionOverview.closeHeader);
                if (closeHeaderButton.length > 0) {
                    await closeHeaderButton[0].click();
                }
            } catch (e) {
                await Misc.processFailure(this);
                throw e;
            }

        });

        let sslConn: interfaces.IDBConnection;

        beforeEach(async function () {

            try {
                await dbConnectionOverview.toolbar.editorSelector
                    .selectEditor(new RegExp(constants.dbConnectionsLabel));
            } catch (e) {
                await Misc.processFailure(this);
                throw e;
            }

        });

        afterEach(async function () {

            if (this.currentTest.state === "failed") {
                await Misc.processFailure(this);
            }

            if (existsInQueue) {
                await TestQueue.pop(this.currentTest.title);
                existsInQueue = false;
            }

        });

        after(async () => {

            await Workbench.openMySQLShellForVSCode();

        });

        it("MySQL Database connection - Verify mandatory fields", async () => {

            await driver.findElement(locator.dbConnectionOverview.newDBConnection).click();
            const conDialog = await driver.wait(until.elementLocated(locator.dbConnectionDialog.exists),
                constants.wait5seconds, "Connection dialog was not displayed");

            const caption = await conDialog.findElement(locator.dbConnectionDialog.caption);
            const hostname = await conDialog.findElement(locator.dbConnectionDialog.mysql.basic.hostname);

            await DialogHelper.clearInputField(caption);
            await DialogHelper.clearInputField(hostname);

            await conDialog.findElement(locator.dbConnectionDialog.ok).click();
            await driver.wait(async () => {
                return (await conDialog.findElements(locator.dbConnectionDialog.errorMessage)).length > 0;
            }, constants.wait5seconds, "The DB Connection dialog should have errors");

            const dialogErrors = await conDialog.findElements(locator.dbConnectionDialog.errorMessage);
            const errorMsgs = await Promise.all(
                dialogErrors.map((item: WebElement) => {
                    return item.getText();
                }));
            expect(errorMsgs, `Could not find the error message 'The user name must not be empty' on the dialog`)
                .to.include("The user name must not be empty");
            expect(await caption.getAttribute("value"), errors.captionError("New Connection",
                await caption.getAttribute("value"))).to.include("New Connection");
            let error = `The hostname should be 'localhost'`;
            error += ` but found ${await hostname.getAttribute("value")}`;
            expect(await hostname.getAttribute("value"), error).to.equals("localhost");
            await conDialog.findElement(locator.dbConnectionDialog.cancel).click();

        });

        it("SQLite Database connection - Verify mandatory fields", async () => {

            await driver.findElement(locator.dbConnectionOverview.newDBConnection).click();
            const conDialog = await driver.wait(until.elementLocated(locator.dbConnectionDialog.exists),
                constants.wait5seconds, "Connection dialog was not displayed");

            await conDialog.findElement(locator.dbConnectionDialog.databaseType).click();
            const popup = await driver.wait(until.elementLocated(locator.dbConnectionDialog.databaseTypeList),
                constants.wait5seconds, "Database type popup was not found");
            await popup.findElement(locator.dbConnectionDialog.databaseTypeSqlite).click();

            const caption = await conDialog.findElement(locator.dbConnectionDialog.caption);
            await DialogHelper.clearInputField(caption);

            await conDialog.findElement(locator.dbConnectionDialog.ok).click();
            await driver.wait(async () => {
                return (await conDialog.findElements(locator.dbConnectionDialog.errorMessage)).length > 0;
            }, constants.wait5seconds, "The DB Connection dialog should have errors");

            const dialogErrors = await conDialog.findElements(locator.dbConnectionDialog.errorMessage);
            const errorMsgs = await Promise.all(
                dialogErrors.map((item: WebElement) => {
                    return item.getText();
                }));
            expect(await caption.getAttribute("value"), errors.captionError("New Connection",
                await caption.getAttribute("value"))).to.include("New Connection");
            expect(errorMsgs, "'Specify the path to an existing Sqlite DB file' error was not found on the dialog")
                .to.include("Specify the path to an existing Sqlite DB file");
            await conDialog.findElement(locator.dbConnectionDialog.cancel).click();

        });

        it("Connect to SQLite database", async () => {

            const sqliteConn = Object.assign({}, globalConn);
            sqliteConn.dbType = "Sqlite";
            sqliteConn.caption = `e2eSqliteConnection`;

            if (Os.isLinux()) {
                process.env.USERPROFILE = process.env.HOME;
            }

            sqliteConn.basic = {
                dbPath: join(process.env.TEST_RESOURCES_PATH,
                    `mysqlsh-${String(process.env.TEST_SUITE)}`,
                    "plugin_data", "gui_plugin", "mysqlsh_gui_backend.sqlite3"),
                dbName: "SQLite",
            };
            await driver.findElement(locator.dbConnectionOverview.newDBConnection).click();
            await DatabaseConnectionDialog.setConnection(sqliteConn);
            const sqliteWebConn = dbConnectionOverview.getConnection(sqliteConn.caption);

            await driver.executeScript(
                "arguments[0].click();",
                sqliteWebConn,
            );

            const notebook = new E2ENotebook();
            await driver.wait(notebook.untilIsOpened(globalConn), constants.wait15seconds);
            await dbTreeSection.focus();
            await dbTreeSection.clickToolbarButton(constants.reloadConnections);
            await driver.wait(new Condition("", async () => {
                const item = await dbTreeSection.tree.getElement(sqliteConn.caption);
                await item.expand();

                return item.isExpanded();
            }), constants.wait10seconds, `${sqliteConn.caption} was not expanded`);

            await driver.wait(new Condition("", async () => {
                const item = await dbTreeSection.tree.getElement("main");
                await item.expand();

                return item.isExpanded();
            }), constants.wait10seconds, `main was not expanded`);

            await driver.wait(new Condition("", async () => {
                const item = await dbTreeSection.tree.getElement("Tables");
                await item.expand();

                return item.isExpanded();
            }), constants.wait10seconds, `Tables was not expanded`);

            const treeDBConn = await dbTreeSection.tree.getElement("db_connection");
            await dbTreeSection.tree.openContextMenuAndSelect(treeDBConn, constants.selectRowsInNotebook);
            await driver.wait(notebook.untilIsOpened(globalConn), constants.wait15seconds);
            await notebook.codeEditor.loadCommandResults();
            const result = await notebook.codeEditor.getLastExistingCommandResult(true);
            expect(result.toolbar.status).to.match(/OK/);
        });

        it("Connect to MySQL database using SSL", async () => {

            sslConn = Object.assign({}, globalConn);
            sslConn.caption = `e2eSSLConnection`;

            sslConn.ssl = {
                mode: "Require and Verify CA",
                caPath: String(process.env.SSL_CA_CERT_PATH),
                clientCertPath: String(process.env.SSL_CLIENT_CERT_PATH),
                clientKeyPath: String(process.env.SSL_CLIENT_KEY_PATH),
            };

            await driver.findElement(locator.dbConnectionOverview.newDBConnection).click();
            await DatabaseConnectionDialog.setConnection(sslConn);
            const dbConn = dbConnectionOverview.getConnection(sslConn.caption);

            await driver.executeScript("arguments[0].click();", dbConn);
            const notebook = new E2ENotebook();
            await driver.wait(notebook.untilIsOpened(globalConn), constants.wait15seconds);
            const query =
                `select * from performance_schema.session_status where variable_name in
                ("ssl_cipher") and variable_value like "%TLS%" `;

            await notebook.codeEditor.create();
            const result = await notebook.codeEditor.execute(query);
            expect(result.toolbar.status).to.match(/1 record retrieved/);
        });

        it("Copy paste and cut paste into the DB Connection dialog", async function () {

            await TestQueue.push(this.test.title);
            existsInQueue = true;
            await driver.wait(TestQueue.poll(this.test.title), constants.queuePollTimeout);

            await driver.findElement(locator.dbConnectionOverview.newDBConnection).click();
            const conDialog = await driver.wait(until.elementLocated(locator.dbConnectionDialog.exists),
                constants.wait5seconds, "Connection dialog was not displayed");
            const hostNameInput = await conDialog.findElement(locator.dbConnectionDialog.mysql.basic.hostname);
            const valueToCopy = await hostNameInput.getAttribute("value");
            await driver.wait(async () => {
                await Os.keyboardSelectAll(hostNameInput);
                await Os.keyboardCopy(hostNameInput);
                const usernameInput = await conDialog.findElement(locator.dbConnectionDialog.mysql.basic.username);
                await Os.keyboardPaste(usernameInput);

                return (await usernameInput.getAttribute("value")).includes(valueToCopy);
            }, constants.wait15seconds, `Could not copy paste ${valueToCopy} to user name field`);

            expect(await hostNameInput.getAttribute("value"),
                "Hostname value should stay the same after copying it to the clipboard").to.equal(valueToCopy);
            const descriptionInput = await conDialog.findElement(locator.dbConnectionDialog.description);
            await DialogHelper.clearInputField(descriptionInput);
            await descriptionInput.sendKeys("testing");
            const valueToCut = await descriptionInput.getAttribute("value");
            await Os.keyboardSelectAll(descriptionInput);
            await Os.keyboardCut(descriptionInput);
            expect(await descriptionInput.getAttribute("value"), "Description value was not cut").to.equals("");
            const schemaInput = await conDialog.findElement(locator.dbConnectionDialog.mysql.basic.defaultSchema);
            await Os.keyboardPaste(schemaInput);
            expect(await schemaInput.getAttribute("value"),
                "Hostname value was not pasted to the description field").to.include(valueToCut);
            await conDialog.findElement(locator.dbConnectionDialog.cancel).click();

        });

        it("Edit a MySQL connection", async () => {

            const editConn: interfaces.IDBConnection = {
                dbType: "MySQL",
                caption: `e2eConnectionToEdit`,
                description: "Local connection",
                basic: {
                    hostname: String(process.env.DBHOSTNAME),
                    username: String(process.env.DBUSERNAME),
                    port: Number(process.env.DBPORT),
                    schema: "sakila",
                    password: String(process.env.DBPASSWORD),
                },
            };

            await driver.findElement(locator.dbConnectionOverview.newDBConnection).click();
            await DatabaseConnectionDialog.setConnection(editConn);
            await dbConnectionOverview.moreActions(editConn.caption, constants.editConnection);
            editConn.caption = "e2eEditedCaption";
            editConn.description = "edited description";
            if (interfaces.isMySQLConnection(editConn.basic)) {
                editConn.basic.hostname = "hostname edited";
                editConn.basic.username = "username edited";
                editConn.basic.schema = "edited schema";
                editConn.basic.protocol = "mysqlx";
                editConn.basic.port = 3305;
                editConn.basic.sshTunnel = true;
                editConn.basic.ociBastion = true;
                editConn.ssl = {
                    mode: "Require",
                    ciphers: "ciphers, edited",
                    caPath: "ca edited",
                    clientCertPath: "cert edited",
                    clientKeyPath: "key edited",
                };
                editConn.ssh = {
                    uri: "edited uri",
                    privateKey: "edited private key",
                    customPath: "edited custom path",
                };
                editConn.advanced = {
                    // bug : https://mybug.mysql.oraclecorp.com/orabugs/site/bug.php?id=36482559
                    /*mode: {
                        ansi: true,
                        traditional: true,
                        allowInvalidDates: true,
                        ansiQuotes: true,
                        errorForDivisionByZero: true,
                        highNotPrecedence: true,
                        ignoreSpace: true,
                        noAutoValueOnZero: true,
                        noUnsignedSubtraction: true,
                        noZeroDate: true,
                        noZeroInDate: true,
                        onlyFullGroupBy: true,
                        padCharToFullLength: true,
                        pipesAsConcat: true,
                        realAsFloat: true,
                        strictAllTables: true,
                        strictTransTables: true,
                        timeTruncateFractional: true,
                    },
                    timeout: "5",*/
                    mode: {
                        ansi: false,
                        traditional: false,
                        allowInvalidDates: false,
                        ansiQuotes: false,
                        errorForDivisionByZero: false,
                        highNotPrecedence: false,
                        ignoreSpace: false,
                        noAutoValueOnZero: false,
                        noUnsignedSubtraction: false,
                        noZeroDate: false,
                        noZeroInDate: false,
                        onlyFullGroupBy: false,
                        padCharToFullLength: false,
                        pipesAsConcat: false,
                        realAsFloat: false,
                        strictAllTables: false,
                        strictTransTables: false,
                        timeTruncateFractional: false,
                    },
                    timeout: "0",
                    compression: "Required",
                    compressionLevel: "5",
                    disableHeatWave: true,
                };
                editConn.mds = {
                    profile: "E2ETESTS",
                    sshPrivateKey: "edited private key",
                    sshPublicKey: "edited public key",
                    // eslint-disable-next-line max-len
                    dbSystemOCID: "ocid1.mysqldbsystem.oc1.iad.aaaaaaaakj7775hxfupaggyci4x2nze45gaqyhcufae23fm5fl2bynwy4tpq",
                    bastionOCID: "ocid1.bastion.oc1.iad.amaaaaaaumfjfyaaectz7jrnfnuses2qc6qvg6ksseu6i2xfow2cnqpbn44q",
                };
            }
            delete (editConn.basic as interfaces.IConnBasicMySQL).password;
            const dbConnectionDialog = DatabaseConnectionDialog;
            await dbConnectionDialog.setConnection(editConn);
            await dbConnectionOverview.moreActions(editConn.caption, constants.editConnection);
            const verifyConn = await dbConnectionDialog.getConnectionDetails();
            expect(verifyConn).to.deep.equal(editConn);

        });

        it("Edit an Sqlite connection", async () => {

            const editSqliteConn: interfaces.IDBConnection = {
                dbType: "Sqlite",
                caption: `e2eSqliteConnectionToEdit`,
                description: "Local connection",
                basic: {
                    dbPath: join(process.env.TEST_RESOURCES_PATH,
                        `mysqlsh-${String(process.env.TEST_SUITE)}`,
                        "plugin_data", "gui_plugin", "mysqlsh_gui_backend.sqlite3"),
                    dbName: "SQLite",
                },
                advanced: {
                    params: "one parameter",
                },
            };

            const dbConnectionDialog = DatabaseConnectionDialog;
            await driver.findElement(locator.dbConnectionOverview.newDBConnection).click();
            await dbConnectionDialog.setConnection(editSqliteConn);
            await dbConnectionOverview.moreActions(editSqliteConn.caption, constants.editConnection);
            editSqliteConn.caption = "e2eEditedSqliteCaption";
            editSqliteConn.description = "edited sqlite description";
            if (interfaces.isSQLiteConnection(editSqliteConn.basic)) {
                editSqliteConn.basic.dbPath = "edited path";
                // https://mybug.mysql.oraclecorp.com/orabugs/site/bug.php?id=36492230
                // editConn.basic.dbName = "edited name";
            }
            if (interfaces.isAdvancedSqlite(editSqliteConn.advanced)) {
                editSqliteConn.advanced.params = "another param";
            }

            await dbConnectionDialog.setConnection(editSqliteConn);
            await dbConnectionOverview.moreActions(editSqliteConn.caption, constants.editConnection);
            const verifyConn = await dbConnectionDialog.getConnectionDetails();
            delete (verifyConn.basic as interfaces.IConnBasicSqlite).dbName;
            delete (editSqliteConn.basic as interfaces.IConnBasicSqlite).dbName;
            expect(verifyConn).to.deep.equal(editSqliteConn);

        });

        it("Duplicate a MySQL Connection", async () => {

            await dbConnectionOverview.moreActions(globalConn.caption, constants.dupConnection);
            const duplicate: interfaces.IDBConnection = {
                dbType: "MySQL",
                caption: "e2eDuplicateFromGlobal",
                basic: {
                    hostname: "localhost",
                    username: String(process.env.DBUSERNAME),
                },
            };
            await DatabaseConnectionDialog.setConnection(duplicate);
            await driver.wait(dbConnectionOverview.untilConnectionExists(duplicate.caption), constants.wait5seconds);

        });

        it("Duplicate a Sqlite Connection", async () => {

            const sqliteConn: interfaces.IDBConnection = {
                dbType: "Sqlite",
                caption: `e2eSqliteConnectionToDuplicate`,
                description: "Local connection",
                basic: {
                    dbPath: join(process.env.TEST_RESOURCES_PATH,
                        `mysqlsh-${String(process.env.TEST_SUITE)}`,
                        "plugin_data", "gui_plugin", "mysqlsh_gui_backend.sqlite3"),
                    dbName: "SQLite",
                },
                advanced: {
                    params: "one parameter",
                },
            };

            const dbConnectionDialog = DatabaseConnectionDialog;
            await driver.findElement(locator.dbConnectionOverview.newDBConnection).click();
            await dbConnectionDialog.setConnection(sqliteConn);
            await dbConnectionOverview.moreActions(sqliteConn.caption, constants.dupConnection);
            const duplicateSqlite: interfaces.IDBConnection = {
                dbType: "Sqlite",
                caption: "e2eDuplicateSqliteFromGlobal",
            };
            await dbConnectionDialog.setConnection(duplicateSqlite);
            await driver.wait(dbConnectionOverview.untilConnectionExists(duplicateSqlite.caption),
                constants.wait5seconds);

        });

        it("Remove a MySQL connection", async () => {

            const connectionToRemove: interfaces.IDBConnection = {
                dbType: "MySQL",
                caption: `e2eConnectionToRemove`,
                description: "Local connection",
                basic: {
                    hostname: String(process.env.DBHOSTNAME),
                    username: String(process.env.DBUSERNAME),
                },
            };

            await driver.findElement(locator.dbConnectionOverview.newDBConnection).click();
            await DatabaseConnectionDialog.setConnection(connectionToRemove);
            await dbConnectionOverview.moreActions(connectionToRemove.caption, constants.removeConnection);
            const dialog = await driver.wait(until.elementLocated(locator.confirmDialog.exists),
                constants.wait5seconds, "confirm dialog was not found");

            await dialog.findElement(locator.confirmDialog.accept).click();
            expect(await dbConnectionOverview.existsConnection(connectionToRemove.caption)).to.be.false;

        });

        it("Remove a Sqlite connection", async () => {

            const sqliteConnToRemove: interfaces.IDBConnection = {
                dbType: "Sqlite",
                caption: `e2eSqliteConnectionToEdit`,
                description: "Local connection",
                basic: {
                    dbPath: join(process.env.TEST_RESOURCES_PATH,
                        `mysqlsh-${String(process.env.TEST_SUITE)}`,
                        "plugin_data", "gui_plugin", "mysqlsh_gui_backend.sqlite3"),
                    dbName: "SQLite",
                },
            };

            await driver.findElement(locator.dbConnectionOverview.newDBConnection).click();
            await DatabaseConnectionDialog.setConnection(sqliteConnToRemove);
            await dbConnectionOverview.moreActions(sqliteConnToRemove.caption, constants.removeConnection);
            const dialog = await driver.wait(until.elementLocated(locator.confirmDialog.exists),
                constants.wait5seconds, "confirm dialog was not found");

            await dialog.findElement(locator.confirmDialog.accept).click();
            expect(await dbConnectionOverview.existsConnection(sqliteConnToRemove.caption)).to.be.false;

        });

        it("Create new notebook", async () => {

            const connection = await dbConnectionOverview.getConnection(globalConn.caption);
            const newNotebook = await connection.findElement(locator.dbConnectionOverview.dbConnection.newNotebook);
            await driver.actions().move({ origin: newNotebook }).perform();
            await driver.wait(until.elementIsVisible(newNotebook), constants.wait5seconds,
                "New notebook button was not visible");
            await newNotebook.click();
            await driver.wait(new E2ENotebook().untilIsOpened(globalConn), constants.wait5seconds);
            const openEditorsSection = new E2EAccordionSection(constants.openEditorsTreeSection);
            const dbNotebook = await openEditorsSection.tree.getElement(constants.openEditorsDBNotebook);
            expect(dbNotebook).to.exist;

        });

        it("Create new script", async () => {

            const connection = await dbConnectionOverview.getConnection("e2eDuplicateFromGlobal");
            const newScript = await connection.findElement(locator.dbConnectionOverview.dbConnection.newScript);
            await driver.actions().move({ origin: newScript }).perform();
            await driver.wait(until.elementIsVisible(newScript), constants.wait5seconds,
                "New script button was not visible");
            await driver.executeScript("arguments[0].click()", newScript);
            await driver.wait(new Script().untilIsOpened(globalConn), constants.wait5seconds);
            const openEditorsSection = new E2EAccordionSection(constants.openEditorsTreeSection);
            await openEditorsSection.focus();
            const script = await openEditorsSection.tree.getElement("Script");
            expect(script).to.exist;

        });

        it("Open new shell console", async () => {

            await driver.wait(until.elementLocated(locator.dbConnectionOverview.newConsoleButton),
                constants.wait10seconds).click();
            await driver.wait(new E2EShellConsole().untilIsOpened(),
                constants.wait15seconds, "Shell Console was not loaded");

        });

    });

    describe("MySQL Administration", () => {

        const toolbar = new Toolbar();

        before(async function () {

            try {
                await Os.deleteCredentials();
                await Workbench.closeAllEditors();
                await dbTreeSection.focus();
                await dbTreeSection.clickToolbarButton(constants.collapseAll);
                const treeGlobalConn = await dbTreeSection.tree.getElement(globalConn.caption);
                await dbTreeSection.tree.expandDatabaseConnection(treeGlobalConn,
                    (globalConn.basic as interfaces.IConnBasicMySQL).password);

                const treeMySQLAdmin = await dbTreeSection.tree.getElement(constants.mysqlAdmin);
                await treeMySQLAdmin.expand();
            } catch (e) {
                await Misc.processFailure(this);
                throw e;
            }

        });

        afterEach(async function () {

            if (this.currentTest.state === "failed") {
                await Misc.processFailure(this);
            }

        });

        after(async function () {

            try {
                const treeGlobalConn = await dbTreeSection.tree.getElement(globalConn.caption);
                await treeGlobalConn.collapse();
                await Workbench.closeAllEditors();
            } catch (e) {
                await Misc.processFailure(this);
                throw e;
            }

        });

        it("Server Status", async () => {

            await (await dbTreeSection.tree.getElement(constants.serverStatus)).click();
            const serverStatus = new E2EServerStatus();
            await driver.wait(serverStatus.untilIsOpened(globalConn), constants.wait15seconds);
            expect((await toolbar.editorSelector.getCurrentEditor()).label,
                `The current editor name should be ${constants.serverStatus}`)
                .to.equals(constants.serverStatus);

            await serverStatus.create();
            expect(serverStatus.host).to.not.equals("");
            expect(serverStatus.socket).to.match(/(\.sock|MySQL)/);
            expect(serverStatus.port).to.match(/(\d+)/);
            expect(serverStatus.version).to.match(/(\d+).(\d+).(\d+)/);
            expect(serverStatus.compiledFor).to.not.equals("");
            expect(serverStatus.configurationFile).to.not.equals("");
            expect(serverStatus.runningSince).to.match(/(\d+) (day|days), (\d+) (hour|hours), (\d+) (minute|minutes)/);
            expect(serverStatus.baseDirectory).to.match(/((?:[^\\/]*\/)*)(.*)/);
            expect(serverStatus.dataDirectory).to.match(/((?:[^\\/]*\/)*)(.*)/);
            expect(serverStatus.pluginsDirectory).to.match(/((?:[^\\/]*\/)*)(.*)/);
            expect(serverStatus.tempDirectory).to.match(/((?:[^\\/]*\/)*)(.*)/);
            expect(serverStatus.errorLog.checked).to.be;
            expect(serverStatus.errorLog.path).to.match(/((?:[^\\/]*\/)*)(.*)/);
            expect(typeof serverStatus.generalLog.checked).to.equals("boolean");
            expect(serverStatus.generalLog.path).to.not.equals("");
            expect(typeof serverStatus.slowQueryLog.checked).to.equals("boolean");
            expect(serverStatus.slowQueryLog.path).to.not.equals("");
            expect(typeof serverStatus.performanceSchema).to.equals("boolean");
            expect(typeof serverStatus.threadPool).to.equals("boolean");
            expect(serverStatus.memCachedPlugin).to.not.equals("");
            expect(serverStatus.semiSyncRepPlugin).to.not.equals("");
            expect(typeof serverStatus.pamAuthentication).to.equals("boolean");
            expect(typeof serverStatus.passwordValidation).to.equals("boolean");
            expect(typeof serverStatus.auditLog).to.equals("boolean");
            expect(serverStatus.firewall).to.not.equals("");
            expect(serverStatus.firewallTrace).to.not.equals("");
            expect(serverStatus.sslCa).to.match(/.pem/);
            expect(serverStatus.sslCert).to.match(/.pem/);
            expect(serverStatus.sslKey).to.match(/.pem/);
            expect(serverStatus.privateKey).to.equals("private_key.pem");
            expect(serverStatus.publicKey).to.equals("public_key.pem");

        });

        it("Client Connections", async () => {

            await (await dbTreeSection.tree.getElement(constants.clientConns)).click();
            const clientConnections = new E2EClientConnections();
            await driver.wait(clientConnections.untilIsOpened(globalConn), constants.wait15seconds);
            expect((await toolbar.editorSelector.getCurrentEditor()).label,
                `The current editor name should be ${constants.clientConns}`)
                .to.equals(constants.clientConns);

            await clientConnections.create();
            expect(clientConnections.threadsConnected).to.match(/Threads Connected: (\d+)/);
            expect(clientConnections.threadsRunning).to.match(/Threads Running: (\d+)/);
            expect(clientConnections.threadsCreated).to.match(/Threads Created: (\d+)/);
            expect(clientConnections.rejected).to.match(/Rejected \(over limit\):/);
            expect(clientConnections.totalConnections).to.match(/Total Connections: (\d+)/);
            expect(clientConnections.connectionLimit).to.match(/Connection Limit: (\d+)/);
            expect(clientConnections.abortedClients).to.match(/Aborted Clients: (\d+)/);
            expect(clientConnections.abortedConnections).to.match(/Aborted Connections: (\d+)/);
            expect(clientConnections.errors).to.match(/Errors: (\d+)/);
            expect((await clientConnections.connectionsList
                .findElements(locator.mysqlAdministration.clientConnections.tableRow)).length).to.be.greaterThan(0);
        });

        it("Performance Dashboard - MLE Disabled", async () => {

            await (await dbTreeSection.tree.getElement(constants.perfDash)).click();
            const performanceDashboard = new E2EPerformanceDashboard();
            await driver.wait(performanceDashboard.untilIsOpened(globalConn), constants.wait15seconds);
            expect(await performanceDashboard.tabExists(constants.perfDashMLETab)).to.be.false;

            await performanceDashboard.loadServerPerformance();
            expect(performanceDashboard.networkStatus.incomingNetworkTrafficGraph).to.exist;
            expect(performanceDashboard.networkStatus.incomingData).to.match(/(\d+) B\/s/);
            expect(performanceDashboard.networkStatus.outgoingNetworkTrafficGraph).to.exist;
            expect(performanceDashboard.networkStatus.outgoingData).to.match(/(\d+) B\/s/);
            expect(performanceDashboard.mysqlStatus.tableCacheGraph).to.exist;
            expect(performanceDashboard.mysqlStatus.threadsGraph).to.exist;
            expect(performanceDashboard.mysqlStatus.openObjectsGraph).to.exist;
            expect(performanceDashboard.mysqlStatus.cacheEfficiency).to.match(/(\d+)%/);
            expect(performanceDashboard.mysqlStatus.totalOpenedTables).to.match(/(\d+)/);
            expect(performanceDashboard.mysqlStatus.totalTransactions).to.match(/(\d+)/);
            expect(performanceDashboard.mysqlStatus.sqlStatementsExecutedGraph).to.exist;
            expect(performanceDashboard.mysqlStatus.totalStatements).to.match(/(\d+)\/s/);
            expect(performanceDashboard.mysqlStatus.select).to.match(/(\d+)\/s/);
            expect(performanceDashboard.mysqlStatus.insert).to.match(/(\d+)\/s/);
            expect(performanceDashboard.mysqlStatus.update).to.match(/(\d+)\/s/);
            expect(performanceDashboard.mysqlStatus.delete).to.match(/(\d+)\/s/);
            expect(performanceDashboard.mysqlStatus.create).to.match(/(\d+)\/s/);
            expect(performanceDashboard.mysqlStatus.alter).to.match(/(\d+)\/s/);
            expect(performanceDashboard.mysqlStatus.drop).to.match(/(\d+)\/s/);
            expect(performanceDashboard.innoDBStatus.innoDBBufferPoolGraph).to.exist;
            expect(performanceDashboard.innoDBStatus.checkpointAgeGraph).to.exist;
            expect(performanceDashboard.innoDBStatus.diskReadRatioGraph).to.exist;
            expect(performanceDashboard.innoDBStatus.readRequests).to.match(/(\d+) pages\/s/);
            expect(performanceDashboard.innoDBStatus.writeRequests).to.match(/(\d+) pages\/s/);
            expect(performanceDashboard.innoDBStatus.diskReads).to.match(/(\d+) #\/s/);
            expect(performanceDashboard.innoDBStatus.innoDBDiskWritesGraph).to.exist;
            expect(performanceDashboard.innoDBStatus.logDataWritten).to.match(/(\d+) B\/s/);
            expect(performanceDashboard.innoDBStatus.logWrites).to.match(/(\d+) #\/s/);
            expect(performanceDashboard.innoDBStatus.writing).to.match(/(\d+) B\/s/);
            expect(performanceDashboard.innoDBStatus.innoDBDiskReadsGraph).to.exist;
            expect(performanceDashboard.innoDBStatus.bufferWrites).to.match(/(\d+) B\/s/);
            expect(performanceDashboard.innoDBStatus.reading).to.match(/(\d+) B\/s/);
            await Workbench.closeEditor(new RegExp(constants.perfDash));

        });

        it("Performance Dashboard - MLE Enabled", async () => {

            let host = await dbTreeSection.tree.getElement(globalConn.caption);
            await (await dbTreeSection.tree.getActionButton(host, constants.openNewConnection)).click();
            let notebook = new E2ENotebook();
            await driver.wait(notebook.untilIsOpened(globalConn), constants.wait10seconds);
            await notebook.codeEditor.loadCommandResults();
            let result = await notebook.codeEditor.execute(`INSTALL COMPONENT "file://component_mle";`);
            expect(result.text).to.match(/OK/);

            await (await dbTreeSection.tree.getElement(constants.perfDash)).click();
            const performanceDashboard = new E2EPerformanceDashboard();
            await driver.wait(performanceDashboard.untilIsOpened(globalConn), constants.wait15seconds);
            expect((await toolbar.editorSelector.getCurrentEditor()).label,
                `The current editor name should be ${constants.perfDash}`)
                .to.equals(constants.perfDash);

            expect(await performanceDashboard.tabExists(constants.perfDashServerTab)).to.be.true;
            expect(await performanceDashboard.tabExists(constants.perfDashMLETab)).to.be.true;
            expect(await performanceDashboard.tabIsSelected(constants.perfDashServerTab)).to.be.true;

            await performanceDashboard.loadServerPerformance();
            expect(performanceDashboard.networkStatus.incomingNetworkTrafficGraph).to.exist;
            expect(performanceDashboard.networkStatus.incomingData).to.match(/(\d+) B\/s/);
            expect(performanceDashboard.networkStatus.outgoingNetworkTrafficGraph).to.exist;
            expect(performanceDashboard.networkStatus.outgoingData).to.match(/(\d+) B\/s/);
            expect(performanceDashboard.mysqlStatus.tableCacheGraph).to.exist;
            expect(performanceDashboard.mysqlStatus.threadsGraph).to.exist;
            expect(performanceDashboard.mysqlStatus.openObjectsGraph).to.exist;
            expect(performanceDashboard.mysqlStatus.cacheEfficiency).to.match(/(\d+)%/);
            expect(performanceDashboard.mysqlStatus.totalOpenedTables).to.match(/(\d+)/);
            expect(performanceDashboard.mysqlStatus.totalTransactions).to.match(/(\d+)/);
            expect(performanceDashboard.mysqlStatus.sqlStatementsExecutedGraph).to.exist;
            expect(performanceDashboard.mysqlStatus.totalStatements).to.match(/(\d+)\/s/);
            expect(performanceDashboard.mysqlStatus.select).to.match(/(\d+)\/s/);
            expect(performanceDashboard.mysqlStatus.insert).to.match(/(\d+)\/s/);
            expect(performanceDashboard.mysqlStatus.update).to.match(/(\d+)\/s/);
            expect(performanceDashboard.mysqlStatus.delete).to.match(/(\d+)\/s/);
            expect(performanceDashboard.mysqlStatus.create).to.match(/(\d+)\/s/);
            expect(performanceDashboard.mysqlStatus.alter).to.match(/(\d+)\/s/);
            expect(performanceDashboard.mysqlStatus.drop).to.match(/(\d+)\/s/);
            expect(performanceDashboard.innoDBStatus.innoDBBufferPoolGraph).to.exist;
            expect(performanceDashboard.innoDBStatus.checkpointAgeGraph).to.exist;
            expect(performanceDashboard.innoDBStatus.diskReadRatioGraph).to.exist;
            expect(performanceDashboard.innoDBStatus.readRequests).to.match(/(\d+) pages\/s/);
            expect(performanceDashboard.innoDBStatus.writeRequests).to.match(/(\d+) pages\/s/);
            expect(performanceDashboard.innoDBStatus.diskReads).to.match(/(\d+) #\/s/);
            expect(performanceDashboard.innoDBStatus.innoDBDiskWritesGraph).to.exist;
            expect(performanceDashboard.innoDBStatus.logDataWritten).to.match(/(\d+) B\/s/);
            expect(performanceDashboard.innoDBStatus.logWrites).to.match(/(\d+) #\/s/);
            expect(performanceDashboard.innoDBStatus.writing).to.match(/(\d+) B\/s/);
            expect(performanceDashboard.innoDBStatus.innoDBDiskReadsGraph).to.exist;
            expect(performanceDashboard.innoDBStatus.bufferWrites).to.match(/(\d+) B\/s/);
            expect(performanceDashboard.innoDBStatus.reading).to.match(/(\d+) B\/s/);

            await (await performanceDashboard.getTab(constants.perfDashMLETab)).click();
            await performanceDashboard.loadMLEPerformance();
            expect(performanceDashboard.mlePerformance.heapUsageGraph).to.exist;
            expect(performanceDashboard.mlePerformance.mleStatus).to.equals("Inactive");
            expect(performanceDashboard.mlePerformance.mleMaxHeapSize).to.match(/(\d+).(\d+) GB/);
            expect(performanceDashboard.mlePerformance.mleHeapUtilizationGraph).to.exist;
            expect(performanceDashboard.mlePerformance.currentHeapUsage).to.equals("0%");

            host = await dbTreeSection.tree.getElement(globalConn.caption);
            await (await dbTreeSection.tree.getActionButton(host, constants.openNewConnection)).click();
            notebook = new E2ENotebook();
            await driver.wait(notebook.untilIsOpened(globalConn), constants.wait10seconds);
            await notebook.codeEditor.loadCommandResults();

            const jsFunction =
                `CREATE FUNCTION js_pow(arg1 INT, arg2 INT) 
                    RETURNS INT DETERMINISTIC LANGUAGE JAVASCRIPT 
                    AS 
                    $$
                    let x = Math.pow(arg1, arg2)
                    return x
                    $$; 
                `;

            result = await notebook.codeEditor.executeWithButton(jsFunction, constants.execFullBlockSql);
            expect(result.text).to.match(/OK/);
            result = await notebook.codeEditor.execute("SELECT js_pow(2,3);");
            expect(result.toolbar.status).to.match(/OK/);
            await Workbench.closeEditor(new RegExp(constants.dbDefaultEditor));
            await (await dbTreeSection.tree.getElement(constants.perfDash)).click();
            await (await performanceDashboard.getTab(constants.perfDashMLETab)).click();
            await performanceDashboard.loadMLEPerformance();
            expect(performanceDashboard.mlePerformance.mleStatus).to.equals("Active");
            expect(parseInt(performanceDashboard.mlePerformance.currentHeapUsage.match(/(\d+)/)[1], 10))
                .to.be.greaterThan(0);
        });

        describe("Lakehouse Navigator", () => {

            const heatWaveConn: interfaces.IDBConnection = {
                dbType: "MySQL",
                caption: "e2eHeatWave Connection",
                description: "Local connection",
                basic: {
                    hostname: String(process.env.HWHOSTNAME),
                    username: String(process.env.HWUSERNAME),
                    schema: "e2e_tests",
                    password: String(process.env.HWPASSWORD),
                },
            };

            const newTask: interfaces.INewLoadingTask = {
                name: "another_cookbook",
                description: "How do cook properly",
                targetDatabaseSchema: "e2e_tests",
                formats: "PDF (Portable Document Format Files)",
            };

            const lakeHouseNavigator = new LakeHouseNavigator();
            const fileToUpload = "another_cookbook.pdf";

            before(async function () {

                try {
                    await Workbench.closeAllEditors();
                    await dbTreeSection.clickToolbarButton(constants.collapseAll);
                    await dbTreeSection.createDatabaseConnection(heatWaveConn);
                    const treeConn = await dbTreeSection.tree.getElement(heatWaveConn.caption);
                    await dbTreeSection.tree.expandDatabaseConnection(treeConn,
                        (heatWaveConn.basic as interfaces.IConnBasicMySQL).password);
                    const treeMySQLAdmin = await dbTreeSection.tree.getElement(constants.mysqlAdmin);
                    await treeMySQLAdmin.expand();
                    await (await dbTreeSection.tree.getElement(constants.lakehouseNavigator)).click();
                    expect(await Workbench.getOpenEditorTitles(), errors.tabIsNotOpened(constants.lakehouseNavigator))
                        .to.include(constants.lakehouseNavigator);
                    await driver.wait(new LakeHouseNavigator().untilIsOpened(heatWaveConn), constants.wait15seconds);
                    await (await dbTreeSection.tree.getElement((heatWaveConn.basic as interfaces.IConnBasicMySQL)
                        .schema)).expand();
                    await (await dbTreeSection.tree.getElement("Tables")).expand();

                    if (await dbTreeSection.tree.elementExists(newTask.name)) {
                        const treeTestTable = await dbTreeSection.tree.getElement(newTask.name);
                        await dbTreeSection.tree.openContextMenuAndSelect(treeTestTable, constants.dropTable);
                        await Workbench.pushDialogButton(`Drop ${newTask.name}`);
                        await Workbench.getNotification(`The object ${newTask.name} has been dropped successfully.`);
                        await driver.wait(dbTreeSection.tree.untilDoesNotExist(newTask.name), constants.wait5seconds);
                    }
                    await Workbench.toggleSideBar(false);
                } catch (e) {
                    await Misc.processFailure(this);
                    throw e;
                }

            });

            after(async function () {
                try {
                    await Workbench.toggleSideBar(true);
                    await (await dbTreeSection.tree.getElement((heatWaveConn.basic as interfaces.IConnBasicMySQL)
                        .schema)).expand();
                    await (await dbTreeSection.tree.getElement("Tables")).expand();
                    await driver.wait(dbTreeSection.tree.untilExists(newTask.name), constants.wait5seconds);
                    const treeTestTable = await dbTreeSection.tree.getElement(newTask.name);
                    await dbTreeSection.tree.openContextMenuAndSelect(treeTestTable, constants.dropTable);
                    await Workbench.pushDialogButton(`Drop ${newTask.name}`);
                    await Workbench.getNotification(`The object ${newTask.name} has been dropped successfully.`);
                    await driver.wait(dbTreeSection.tree.untilDoesNotExist(newTask.name), constants.wait5seconds);
                    await Workbench.closeAllEditors();
                } catch (e) {
                    await Misc.processFailure(this);
                    throw e;
                }
            });

            it("Upload data to object storage", async () => {

                await driver.wait(lakeHouseNavigator.overview.isOpened(), constants.wait3seconds);
                await driver.wait(new Condition(`for editor to be ${constants.lakeHouseNavigatorEditor}`, async () => {
                    return (await lakeHouseNavigator.toolbar.editorSelector.getCurrentEditor()).label ===
                        constants.lakeHouseNavigatorEditor;
                }), constants.wait3seconds);

                await lakeHouseNavigator.overview.clickUploadFiles();
                await lakeHouseNavigator.uploadToObjectStorage.objectStorageBrowser.selectOciProfile("HEATWAVE");
                await lakeHouseNavigator.uploadToObjectStorage.objectStorageBrowser.refreshObjectStorageBrowser();
                await driver.wait(lakeHouseNavigator.uploadToObjectStorage.objectStorageBrowser.untilItemsAreLoaded(),
                    constants.wait15seconds);
                await lakeHouseNavigator.uploadToObjectStorage.objectStorageBrowser
                    .openObjectStorageCompartment(["HeatwaveAutoML", "genai-shell-test", "upload"]);
                await (await lakeHouseNavigator.uploadToObjectStorage.getFilesForUploadButton(constants.addFiles))
                    .click();
                await lakeHouseNavigator.uploadToObjectStorage.setFilesForUploadFilePath(join(process.cwd(),
                    fileToUpload));
                await driver.wait(lakeHouseNavigator.uploadToObjectStorage.untilExistsFileForUploadFile(fileToUpload),
                    constants.wait10seconds);
                await lakeHouseNavigator.uploadToObjectStorage.objectStorageBrowser.checkItem("upload");
                await (await lakeHouseNavigator.uploadToObjectStorage
                    .getFilesForUploadButton(constants.startFileUpload)).click();
                await lakeHouseNavigator.uploadToObjectStorage.objectStorageBrowser.refreshObjectStorageBrowser();
                await driver.wait(lakeHouseNavigator.uploadToObjectStorage.objectStorageBrowser.untilItemsAreLoaded(),
                    constants.wait10seconds);
                expect(await lakeHouseNavigator.uploadToObjectStorage.objectStorageBrowser.existsItem(fileToUpload))
                    .to.be.true;
                await driver.wait(Workbench.untilNotificationExists("The files have been uploaded successfully"),
                    constants.wait20seconds);

            });

            it("Load into Lakehouse", async () => {

                await lakeHouseNavigator.selectTab(constants.loadIntoLakeHouseTab);
                await driver.wait(lakeHouseNavigator.loadIntoLakehouse.objectStorageBrowser.untilItemsAreLoaded(),
                    constants.wait10seconds);
                await lakeHouseNavigator.uploadToObjectStorage.objectStorageBrowser
                    .openObjectStorageCompartment(["HeatwaveAutoML", "genai-shell-test", "upload"]);
                expect(await lakeHouseNavigator.loadIntoLakehouse.objectStorageBrowser.existsItem(fileToUpload),
                    `'${fileToUpload}' was not found`).to.be.true;
                await lakeHouseNavigator.loadIntoLakehouse.objectStorageBrowser.checkItem(fileToUpload);
                await driver.wait(lakeHouseNavigator.loadIntoLakehouse.untilExistsLoadingTask(fileToUpload),
                    constants.wait5seconds);
                await lakeHouseNavigator.loadIntoLakehouse.setNewLoadingTask(newTask);
                await lakeHouseNavigator.loadIntoLakehouse.startLoadingTask();

            });

            it("Lakehouse Tables", async () => {

                await driver.wait(lakeHouseNavigator.lakehouseTables.untilIsOpened(), constants.wait15seconds);
                expect(await lakeHouseNavigator.lakehouseTables.getDatabaseSchemas())
                    .to.contain(newTask.targetDatabaseSchema);
                await driver.wait(lakeHouseNavigator.lakehouseTables.untilExistsLakeHouseTable(newTask.name),
                    constants.wait10seconds);
                await driver.wait(lakeHouseNavigator.lakehouseTables.untilLakeHouseTableIsLoading(newTask.name),
                    constants.wait1minute);

                let latestTable = await lakeHouseNavigator.lakehouseTables.getLakehouseTable(newTask.name);
                expect(latestTable.hasProgressBar).to.be.true;
                expect(latestTable.loaded).to.match(/(\d+)%/);
                expect(latestTable.hasLoadingSpinner).to.be.true;
                expect(latestTable.rows).to.equals("-");
                expect(latestTable.size).to.equals("-");
                expect(latestTable.date).to.match(/(\d+)-(\d+)-(\d+) (\d+):(\d+)/);
                expect(latestTable.comment).to.equals(newTask.description);

                await driver.wait(lakeHouseNavigator.lakehouseTables.untilLakeHouseTableIsLoaded(newTask.name),
                    constants.wait2minutes);

                latestTable = await lakeHouseNavigator.lakehouseTables.getLakehouseTable(newTask.name);
                expect(latestTable.hasProgressBar).to.be.false;
                expect(latestTable.loaded).to.equals("Yes");
                expect(latestTable.hasLoadingSpinner).to.be.false;
                expect(latestTable.rows).to.match(/(\d+)/);
                expect(latestTable.size).to.match(/(\d+).(\d+) (KB|MB)/);
                expect(latestTable.date).to.match(/(\d+)-(\d+)-(\d+) (\d+):(\d+)/);
                expect(latestTable.comment).to.equals(newTask.description);

                const latestTask = await lakeHouseNavigator.lakehouseTables.getLatestTask();
                await driver.wait(lakeHouseNavigator.lakehouseTables.untilLakeHouseTaskIsCompleted(latestTask.id),
                    constants.wait10seconds);
                expect(latestTask.name).to.equals(`Loading ${newTask.name}`);
                expect(latestTask.hasProgressBar).to.be.false;
                expect(latestTask.status).to.equals("COMPLETED");
                expect(latestTask.startTime).to.match(/(\d+)-(\d+)-(\d+) (\d+):(\d+)/);
                expect(latestTask.endTime).to.match(/(\d+)-(\d+)-(\d+) (\d+):(\d+)/);
                expect(latestTask.message).to.equals("Task completed.");

            });

        });

    });

    describe("Tree context menu items", () => {

        let treeGlobalSchema: TreeItem;
        let treeGlobalSchemaTables: TreeItem;
        let treeGlobalSchemaViews: TreeItem;
        let treeGlobalConn: TreeItem;
        const dumpFolder = join(constants.workspace, "dump");
        const dumpSchemaToDisk = `dump_schema_to_disk`;
        const schemaForMySQLDbService = "schema_for_mysql_db_service";
        const schemaToDrop = "schema_to_drop";
        const tableToDrop = `table_to_drop`;
        const testView = `test_view`;
        const viewToDrop = "view_to_drop";
        const testRoutine = "test_routine";
        const testEvent = "test_event";
        const dup = "duplicatedConnection";
        const tasksTreeSection = new E2EAccordionSection(constants.tasksTreeSection);
        let existsInQueue = false;

        before(async function () {

            try {
                await Os.deleteCredentials();
                await dbTreeSection.focus();
                const treeGlobalConn = await dbTreeSection.tree.getElement(globalConn.caption);
                await treeGlobalConn.collapse();
                await Workbench.closeAllEditors();
                await dbTreeSection.clickToolbarButton(constants.collapseAll);
                await dbTreeSection.tree.expandDatabaseConnection(treeGlobalConn,
                    (globalConn.basic as interfaces.IConnBasicMySQL).password);
            } catch (e) {
                await Misc.processFailure(this);
                throw e;
            }

        });

        beforeEach(async function () {

            try {
                treeGlobalConn = await dbTreeSection.tree.getElement(globalConn.caption);
            } catch (e) {
                await Misc.processFailure(this);
                throw e;
            }

        });

        afterEach(async function () {

            if (this.currentTest.state === "failed") {
                await Misc.processFailure(this);
            }

            if (existsInQueue) {
                await TestQueue.pop(this.currentTest.title);
                existsInQueue = false;
            }
        });

        after(async () => {

            await fs.rm(dumpFolder, { force: true, recursive: true });

        });

        it("Set this DB Connection as Default", async () => {

            const treeGlobalConn = await dbTreeSection.tree.getElement(globalConn.caption);
            await dbTreeSection.tree.openContextMenuAndSelect(treeGlobalConn, constants.setDBConnDefault);
            await Workbench.getNotification(`"${globalConn.caption}" has been set as default DB Connection`);

        });

        it("Open Database Connection", async () => {

            await dbTreeSection.tree.openContextMenuAndSelect(treeGlobalConn, constants.openNewConnection);
            await driver.wait(new E2ENotebook().untilIsOpened(globalConn), constants.wait15seconds);
            await driver.wait(dbTreeSection.tree.untilExists(globalConn.caption), constants.wait5seconds);

        });

        it("Open MySQL Shell Console for this connection", async () => {

            await dbTreeSection.tree.openContextMenuAndSelect(treeGlobalConn, constants.openShellConnection);
            await driver.wait(new E2EShellConsole().untilIsOpened(globalConn), constants.wait15seconds);
            const treeOpenEditorsSection = new E2EAccordionSection(constants.openEditorsTreeSection);
            await treeOpenEditorsSection.expand();
            await treeOpenEditorsSection.focus();
            const treeOEShellConsoles = await treeOpenEditorsSection.tree.getElement(constants.mysqlShellConsoles);
            expect(await treeOEShellConsoles.findChildItem(`Session to ${String(globalConn.caption)}`),
                errors.doesNotExistOnTree(`Session to ${String(globalConn.caption)}`)).to.exist;
            const treeVisibleItems = await (await treeOpenEditorsSection.getWebElement()).getVisibleItems();
            expect(treeVisibleItems.length, "No tree items were found on OPEN EDITORS section").to.be.at.least(1);
            expect(await treeVisibleItems[0].getLabel(), errors.doesNotExistOnTree(constants.dbConnectionsLabel))
                .to.equals(constants.dbConnectionsLabel);

        });

        it("Edit MySQL connection", async () => {

            await dbTreeSection.clickToolbarButton(constants.collapseAll);
            const localConn = Object.assign({}, globalConn);
            localConn.caption = `e2eConnectionToEdit`;
            await dbTreeSection.createDatabaseConnection(localConn);
            await new DatabaseConnectionOverview().getConnection(localConn.caption);
            const treeLocalConn = await dbTreeSection.tree.getElement(localConn.caption);
            await dbTreeSection.tree.openContextMenuAndSelect(treeLocalConn, constants.editDBConnection);
            await DatabaseConnectionDialog.setConnection(localConn);
            await driver.wait(dbTreeSection.tree.untilExists(localConn.caption), constants.wait5seconds);

        });

        it("Duplicate this MySQL connection", async () => {

            const dupConn = Object.assign({}, globalConn);
            dupConn.caption = dup;
            await dbTreeSection.focus();
            treeGlobalConn = await dbTreeSection.tree.getElement(globalConn.caption);
            await dbTreeSection.tree.openContextMenuAndSelect(treeGlobalConn, constants.duplicateConnection);
            await DatabaseConnectionDialog.setConnection(dupConn);
            await driver.wait(dbTreeSection.tree.untilExists(dup), constants.wait5seconds);

        });

        it("Delete DB connection", async () => {

            await dbTreeSection.focus();
            const treeDup = await dbTreeSection.tree.getElement(dup);
            await dbTreeSection.tree.openContextMenuAndSelect(treeDup, constants.deleteDBConnection);
            await Misc.switchToFrame();
            const dialog = await driver.wait(until.elementLocated(
                locator.confirmDialog.exists), constants.wait15seconds, "confirm dialog was not found");
            await dialog.findElement(locator.confirmDialog.accept).click();
            await driver.wait(dbTreeSection.tree.untilDoesNotExist(dup), constants.wait5seconds);

        });

        it("Load SQL Script from Disk", async () => {

            const notebook = new E2ENotebook();
            const script = "sakila_cst.sql";
            const destFile = join(constants.workspace, "gui", "frontend", "src", "tests", "e2e", "sql", script);
            await dbTreeSection.tree.openContextMenuAndSelect(treeGlobalConn, constants.loadScriptFromDisk);
            await Workbench.setInputPath(destFile);
            await driver.wait(notebook.untilIsOpened(globalConn), constants.wait15seconds);
            await driver.wait(async () => {
                return ((await notebook.toolbar.editorSelector.getCurrentEditor()).label) === script;
            }, constants.wait5seconds, `Current editor is not ${script}`);
            let error = `The current editor type should be 'Mysql',`;
            error += ` but found ${(await notebook.toolbar.editorSelector.getCurrentEditor()).icon}`;
            expect((await notebook.toolbar.editorSelector.getCurrentEditor()).icon, error)
                .to.include(constants.mysqlScriptIcon);
            const scriptLines = await driver.findElements(locator.notebook.codeEditor.editor.line);
            expect(scriptLines.length, "The script was not loaded. No lines found on the editor").to.be.greaterThan(0);
            await notebook.toolbar.editorSelector.selectEditor(new RegExp(constants.openEditorsDBNotebook),
                globalConn.caption);
            await notebook.codeEditor.loadCommandResults();

        });

        it("Set as Current Database Schema", async () => {

            treeGlobalConn = await dbTreeSection.tree.getElement(globalConn.caption);
            await dbTreeSection.tree.expandDatabaseConnection(treeGlobalConn,
                (globalConn.basic as interfaces.IConnBasicMySQL).password);
            const treeSchema = await dbTreeSection.tree
                .getElement((globalConn.basic as interfaces.IConnBasicMySQL).schema);
            await dbTreeSection.tree.openContextMenuAndSelect(treeSchema, constants.setCurrentDBSchema, undefined);
            await driver.wait(dbTreeSection.tree.untilIsDefault("sakila", "schema"), constants.wait5seconds);
            await (await dbTreeSection.tree.getActionButton(treeGlobalConn, constants.openNewConnection)).click();
            await Workbench.openEditor(globalConn.caption);
            const notebook = new E2ENotebook();
            await notebook.codeEditor.create();
            let result = await notebook.codeEditor.execute("select database();");
            expect(result.toolbar.status).to.match(/OK/);
            expect(await result.grid.content.getAttribute("innerHTML"))
                .to.match(new RegExp((globalConn.basic as interfaces.IConnBasicMySQL).schema));
            const otherSchema = await dbTreeSection.tree.getElement("world_x_cst");
            await dbTreeSection.tree.openContextMenuAndSelect(otherSchema, constants.setCurrentDBSchema, undefined);
            await driver.wait(dbTreeSection.tree.untilIsDefault("world_x_cst", "schema"), constants.wait5seconds);
            expect(await dbTreeSection.tree.isElementDefault("sakila", "schema"),
                errors.notDefault("sakila")).to.be.false;
            await Workbench.openEditor(globalConn.caption);
            await notebook.codeEditor.clean();
            result = await notebook.codeEditor.execute("select database();");
            expect(result.toolbar.status).to.match(/OK/);
            expect(await result.grid.content.getAttribute("innerHTML")).to.match(/world_x_cst/);
            await Workbench.closeAllEditors();
            await driver.wait(async () => {
                return !(await dbTreeSection.tree.isElementDefault("world_x_cst", "schema"));
            }, constants.wait5seconds, "world_x_cst should not be the default");
            expect(await dbTreeSection.tree.isElementDefault("sakila", "schema"),
                errors.isDefault("sakila")).to.be.false;

        });

        it("Dump Schema to Disk", async () => {

            const treeTestSchema = await dbTreeSection.tree.getElement(dumpSchemaToDisk);
            treeGlobalSchema = await dbTreeSection.tree.getElement((globalConn.basic as interfaces.IConnBasicMySQL)
                .schema);
            await fs.rm(dumpFolder, { force: true, recursive: true });
            await fs.mkdir(dumpFolder);
            await dbTreeSection.tree.openContextMenuAndSelect(treeTestSchema, constants.dumpSchemaToDisk);
            await Workbench.setInputPath(dumpFolder);
            await Workbench.setInputPassword((globalConn.basic as interfaces.IConnBasicMySQL).password);
            await Workbench.waitForOutputText(`Task 'Dump Schema ${dumpSchemaToDisk} to Disk' completed successfully`,
                constants.wait10seconds);
            const files = await fs.readdir(dumpFolder);
            expect(files.length, `The dump did not exported any files to ${dumpFolder}`).to.be.greaterThan(0);
            await tasksTreeSection.focus();
            await driver.wait(tasksTreeSection.tree.untilExists(`Dump Schema ${dumpSchemaToDisk} to Disk (done)`),
                constants.wait5seconds);
            await dbTreeSection.focus();
            await dbTreeSection.tree.openContextMenuAndSelect(treeTestSchema, constants.dropSchema, undefined);
            await Workbench.pushDialogButton(`Drop ${dumpSchemaToDisk}`);
            await Workbench.getNotification(`The object ${dumpSchemaToDisk} has been dropped successfully.`);
            await driver.wait(dbTreeSection.tree.untilDoesNotExist(dumpSchemaToDisk), constants.wait5seconds);

        });

        it("Load Dump from Disk", async () => {

            await dbTreeSection.clickToolbarButton(constants.reloadConnections);
            await dbTreeSection.tree.openContextMenuAndSelect(treeGlobalConn, constants.loadDumpFromDisk);
            await Workbench.setInputPath(dumpFolder);
            await Workbench.setInputPassword((globalConn.basic as interfaces.IConnBasicMySQL).password);
            await Workbench.waitForOutputText(/Task 'Loading Dump .* from Disk' completed successfully/,
                constants.wait10seconds);
            await tasksTreeSection.focus();
            await driver.wait(tasksTreeSection.tree.untilExists(/Loading Dump (.*) \(done\)/), constants.wait5seconds);
            await dbTreeSection.focus();
            await driver.wait(dbTreeSection.tree.untilExists(dumpSchemaToDisk), constants.wait5seconds);

        });

        it("Dump Schema to Disk for MySQL Database Service", async () => {

            const treeTestSchema = await dbTreeSection.tree.getElement(schemaForMySQLDbService);
            treeGlobalSchema = await dbTreeSection.tree
                .getElement((globalConn.basic as interfaces.IConnBasicMySQL).schema);

            await fs.rm(dumpFolder, { force: true, recursive: true });
            await fs.mkdir(dumpFolder);
            await dbTreeSection.tree.openContextMenuAndSelect(treeTestSchema, constants.dumpSchemaToDiskToService);
            await Workbench.setInputPath(dumpFolder);
            await Workbench.setInputPassword((globalConn.basic as interfaces.IConnBasicMySQL).password);
            await Workbench
                .waitForOutputText(`Task 'Dump Schema ${schemaForMySQLDbService} to Disk' completed successfully`,
                    constants.wait10seconds);
            const files = await fs.readdir(dumpFolder);
            expect(files.length, `The dump did not exported any files to ${dumpFolder}`).to.be.greaterThan(0);
            await tasksTreeSection.focus();
            await driver.wait(tasksTreeSection.tree
                .untilExists(`Dump Schema ${schemaForMySQLDbService} to Disk (done)`), constants.wait5seconds);

            await dbTreeSection.focus();

        });

        it("Load Data to HeatWave Cluster", async () => {

            await dbTreeSection.focus();
            const sakilaItem = await dbTreeSection.tree.getElement(
                (globalConn.basic as interfaces.IConnBasicMySQL).schema);
            await dbTreeSection.tree.openContextMenuAndSelect(sakilaItem, constants.loadDataToHW);
            await DatabaseConnectionDialog.setDataToHeatWave();
            await Workbench.setInputPassword((globalConn.basic as interfaces.IConnBasicMySQL).password);
            await Workbench.getNotification("The data load to the HeatWave cluster operation has finished");
            await new BottomBarPanel().toggle(false);

        });

        it("Drop Schema", async () => {

            const treeTestSchema = await dbTreeSection.tree.getElement(schemaToDrop);
            await dbTreeSection.tree.openContextMenuAndSelect(treeTestSchema, constants.dropSchema, undefined);
            const ntfs = await new extWorkbench().getNotifications();
            if (ntfs.length > 0) {
                await Workbench.clickOnNotificationButton(ntfs[ntfs.length - 1], `Drop ${schemaToDrop}')]`);
            } else {
                await Workbench.pushDialogButton(`Drop ${schemaToDrop}`);
            }
            await Workbench.getNotification(`The object ${schemaToDrop} has been dropped successfully.`);
            await driver.wait(dbTreeSection.tree.untilDoesNotExist(schemaToDrop), constants.wait5seconds);

        });

        it("Schema - Copy name and create statement to clipboard", async function () {

            await TestQueue.push(this.test.title);
            existsInQueue = true;
            await driver.wait(TestQueue.poll(this.test.title), constants.queuePollTimeout);

            await driver.wait(new Condition("", async () => {
                try {
                    treeGlobalSchema = await dbTreeSection.tree
                        .getElement((globalConn.basic as interfaces.IConnBasicMySQL).schema);
                    await dbTreeSection.tree.openContextMenuAndSelect(treeGlobalSchema, [constants.copyToClipboard,
                    constants.copyToClipboardName], constants.schemaCtxMenu);
                    await Workbench.getNotification("The name was copied to the system clipboard");
                    console.log(`clipboard content: ${clipboard.readSync()}`);

                    return clipboard.readSync() === (globalConn.basic as interfaces.IConnBasicMySQL).schema;
                } catch (e) {
                    if (!(errors.isStaleError(e as Error))) {
                        throw e;
                    }
                }
            }), constants.wait25seconds, "The schema name was not copied to the clipboard");

            await driver.wait(new Condition("", async () => {
                try {
                    treeGlobalSchema = await dbTreeSection.tree
                        .getElement((globalConn.basic as interfaces.IConnBasicMySQL).schema);
                    await dbTreeSection.tree.openContextMenuAndSelect(treeGlobalSchema, [constants.copyToClipboard,
                    constants.copyToClipboardStat], constants.schemaCtxMenu);
                    await Workbench.getNotification("The create script was copied to the system clipboard");
                    console.log(`clipboard content: ${clipboard.readSync()}`);

                    return clipboard.readSync().includes("CREATE DATABASE");
                } catch (e) {
                    if (!(errors.isStaleError(e as Error))) {
                        throw e;
                    }
                }
            }), constants.wait25seconds, "The schema create statement was not copied to the clipboard");

        });

        it("Table - Select Rows in DB Notebook", async () => {

            await treeGlobalSchema.expand();
            treeGlobalSchemaTables = await dbTreeSection.tree.getElement("Tables");
            await treeGlobalSchemaTables.expand();
            const actorTable = await dbTreeSection.tree.getElement("actor");
            await dbTreeSection.tree.openContextMenuAndSelect(actorTable, constants.selectRowsInNotebook);
            const notebook = new E2ENotebook();
            await driver.wait(notebook.untilIsOpened(globalConn), constants.wait10seconds);
            await notebook.codeEditor.create();
            const result = await notebook.codeEditor.getLastExistingCommandResult(true);
            expect(result.toolbar.status).to.match(/OK/);

        });

        it("Table - Copy name and create statement to clipboard", async function () {

            await TestQueue.push(this.test.title);
            existsInQueue = true;
            await driver.wait(TestQueue.poll(this.test.title), constants.queuePollTimeout);

            await driver.wait(new Condition("", async () => {
                try {
                    const actorTable = await dbTreeSection.tree.getElement("actor");
                    await dbTreeSection.tree.openContextMenuAndSelect(actorTable, [constants.copyToClipboard,
                    constants.copyToClipboardName], constants.dbObjectCtxMenu);
                    await Workbench.getNotification("The name was copied to the system clipboard");
                    console.log(`clipboard content: ${clipboard.readSync()}`);

                    return clipboard.readSync() === "actor";
                } catch (e) {
                    if (!(errors.isStaleError(e as Error))) {
                        throw e;
                    }
                }
            }), constants.wait25seconds, "The table name was not copied to the clipboard");

            await driver.wait(new Condition("", async () => {
                try {
                    const actorTable = await dbTreeSection.tree.getElement("actor");
                    await dbTreeSection.tree.openContextMenuAndSelect(actorTable, [constants.copyToClipboard,
                    constants.copyToClipboardStat], constants.dbObjectCtxMenu);
                    await Workbench.getNotification("The create script was copied to the system clipboard");
                    console.log(`clipboard content: ${clipboard.readSync()}`);

                    return clipboard.readSync().includes("idx_actor_last_name");
                } catch (e) {
                    if (!(errors.isStaleError(e as Error))) {
                        throw e;
                    }
                }
            }), constants.wait25seconds, "The table create statement was not copied to the clipboard");

        });

        it("Drop Table", async () => {

            const treeTestTable = await dbTreeSection.tree.getElement(tableToDrop);
            await dbTreeSection.tree.openContextMenuAndSelect(treeTestTable, constants.dropTable);
            await Workbench.pushDialogButton(`Drop ${tableToDrop}`);
            await Workbench.getNotification(`The object ${tableToDrop} has been dropped successfully.`);
            await driver.wait(dbTreeSection.tree.untilDoesNotExist(tableToDrop), constants.wait5seconds);

        });

        it("View - Select Rows in DB Notebook", async () => {

            const openEditorsTreeSection = new E2EAccordionSection(constants.openEditorsTreeSection);
            await openEditorsTreeSection.collapse();
            treeGlobalSchemaViews = await dbTreeSection.tree.getElement("Views");
            await treeGlobalSchemaViews.expand();
            const treeTestView = await dbTreeSection.tree.getElement(testView);
            await dbTreeSection.tree.openContextMenuAndSelect(treeTestView, constants.selectRowsInNotebook);
            const notebook = new E2ENotebook();
            await notebook.codeEditor.create();
            const result = await notebook.codeEditor.getLastExistingCommandResult(true);
            expect(result.toolbar.status).to.match(/OK, (\d+) records/);
        });

        it("View - Copy name and create statement to clipboard", async function () {

            await TestQueue.push(this.test.title);
            existsInQueue = true;
            await driver.wait(TestQueue.poll(this.test.title), constants.queuePollTimeout);

            await driver.wait(new Condition("", async () => {
                try {
                    const treeTestView = await dbTreeSection.tree.getElement(testView);
                    await dbTreeSection.tree.openContextMenuAndSelect(treeTestView, [constants.copyToClipboard,
                    constants.copyToClipboardName], constants.dbObjectCtxMenu);
                    await Workbench.getNotification("The name was copied to the system clipboard");
                    console.log(`clipboard content: ${clipboard.readSync()}`);

                    return clipboard.readSync() === testView;
                } catch (e) {
                    if (!(errors.isStaleError(e as Error))) {
                        throw e;
                    }
                }
            }), constants.wait25seconds, "The view name was not copied to the clipboard");

            await driver.wait(new Condition("", async () => {
                try {
                    const treeTestView = await dbTreeSection.tree.getElement(testView);
                    await dbTreeSection.tree.openContextMenuAndSelect(treeTestView, [constants.copyToClipboard,
                    constants.copyToClipboardStat], constants.dbObjectCtxMenu);
                    await Workbench.getNotification("The create script was copied to the system clipboard");
                    console.log(`clipboard content: ${clipboard.readSync()}`);

                    return clipboard.readSync().includes("DEFINER VIEW");
                } catch (e) {
                    if (!(errors.isStaleError(e as Error))) {
                        throw e;
                    }
                }
            }), constants.wait25seconds, "The view create statement was not copied to the clipboard");

        });

        it("Drop View", async () => {

            await dbTreeSection.tree.expandDatabaseConnection(treeGlobalConn,
                (globalConn.basic as interfaces.IConnBasicMySQL).password);
            await treeGlobalSchema.expand();
            await treeGlobalSchemaViews.expand();
            const treeTestView = await dbTreeSection.tree.getElement(viewToDrop);
            await dbTreeSection.tree.openContextMenuAndSelect(treeTestView, constants.dropView);
            await Workbench.pushDialogButton(`Drop ${viewToDrop}`);
            await Workbench.getNotification(`The object ${viewToDrop} has been dropped successfully.`);
            await driver.wait(dbTreeSection.tree.untilDoesNotExist(viewToDrop), constants.wait5seconds);

        });

        it("Table - Show Data", async () => {

            const actorTable = await dbTreeSection.tree.getElement("actor");
            await dbTreeSection.tree.openContextMenuAndSelect(actorTable, constants.showData);
            const result = await new Script().getLastResult();
            expect(result.toolbar.status).to.match(/OK/);
            await driver.wait(result.untilIsMaximized(), constants.wait5seconds);

        });

        it("View - Show Data", async () => {

            const treeTestView = await dbTreeSection.tree.getElement(testView);
            await dbTreeSection.tree.openContextMenuAndSelect(treeTestView, constants.showData);
            await driver.wait(new E2ENotebook().untilIsOpened(globalConn), constants.wait15seconds);
            const result = await new Script().getLastResult();
            expect(result.toolbar.status).to.match(/OK/);
            await driver.wait(result.untilIsMaximized(), constants.wait5seconds);
        });

        it("Routines - Clipboard", async function () {

            await TestQueue.push(this.test.title);
            existsInQueue = true;
            await driver.wait(TestQueue.poll(this.test.title), constants.queuePollTimeout);

            await (await dbTreeSection.tree.getElement("Tables")).collapse();
            const treeRoutines = await dbTreeSection.tree.getElement("Routines");
            await treeRoutines.expand();
            await driver.wait(dbTreeSection.tree.untilExists(testRoutine), constants.wait5seconds);
            await driver.wait(new Condition("", async () => {
                try {
                    const treeTestRoutine = await dbTreeSection.tree.getElement(testRoutine);
                    await dbTreeSection.tree.openContextMenuAndSelect(treeTestRoutine, [constants.copyToClipboard,
                    constants.copyToClipboardName], constants.routinesCtxMenu);
                    await Workbench.getNotification("The name was copied to the system clipboard");

                    return clipboard.readSync() === testRoutine;
                } catch (e) {
                    if (!(errors.isStaleError(e as Error))) {
                        throw e;
                    }
                }

            }), constants.wait15seconds, "The routine name was not copied to the clipboard");

            await driver.wait(new Condition("", async () => {
                try {
                    const treeTestRoutine = await dbTreeSection.tree.getElement(testRoutine);
                    await dbTreeSection.tree.openContextMenuAndSelect(treeTestRoutine, [constants.copyToClipboard,
                    constants.copyToClipboardStat], constants.routinesCtxMenu);
                    await Workbench.getNotification("The create script was copied to the system clipboard");

                    return clipboard.readSync().includes("CREATE DEFINER");
                } catch (e) {
                    if (!(errors.isStaleError(e as Error))) {
                        throw e;
                    }
                }
            }), constants.wait15seconds, "The routine create statement was not copied to the clipboard");

            await driver.wait(new Condition("", async () => {
                try {
                    const treeTestRoutine = await dbTreeSection.tree.getElement(testRoutine);
                    await dbTreeSection.tree.openContextMenuAndSelect(treeTestRoutine, [constants.copyToClipboard,
                    constants.copyToClipboardStatDel], constants.routinesCtxMenu);
                    await Workbench.getNotification("The create script was copied to the system clipboard");

                    return clipboard.readSync().includes("DELIMITER");
                } catch (e) {
                    if (!(errors.isStaleError(e as Error))) {
                        throw e;
                    }
                }
            }), constants.wait15seconds,
                "The routine create statement with delimiters was not copied to the clipboard");

            await driver.wait(new Condition("", async () => {
                try {
                    const treeTestRoutine = await dbTreeSection.tree.getElement(testRoutine);
                    await dbTreeSection.tree.openContextMenuAndSelect(treeTestRoutine, [constants.copyToClipboard,
                    constants.copyToClipboardDropStatDel], constants.routinesCtxMenu);
                    await Workbench.getNotification("The create script was copied to the system clipboard");

                    return clipboard.readSync().includes("DROP") && clipboard.readSync().includes("DELIMITER");
                } catch (e) {
                    if (!(errors.isStaleError(e as Error))) {
                        throw e;
                    }
                }
            }), constants.wait15seconds,
                "The routine drop & create statement with delimiters was not copied to the clipboard");

        });

        it("Routines - Drop Routine", async () => {

            const treeTestRoutine = await dbTreeSection.tree.getElement(testRoutine);
            await dbTreeSection.tree.openContextMenuAndSelect(treeTestRoutine, constants.dropStoredRoutine);
            await Workbench.pushDialogButton(`Drop ${testRoutine}`);
            await Workbench.getNotification(`The object ${testRoutine} has been dropped successfully.`);
            await driver.wait(dbTreeSection.tree.untilDoesNotExist(testRoutine), constants.wait5seconds);

        });

        it("Drop Event", async () => {

            const treeRoutines = await dbTreeSection.tree.getElement("Routines");
            await treeRoutines.collapse();
            const treeEvents = await dbTreeSection.tree.getElement("Events");
            await treeEvents.expand();
            await driver.wait(dbTreeSection.tree.untilExists(testEvent), constants.wait5seconds);
            const treeTestEvent = await dbTreeSection.tree.getElement(testEvent);
            await dbTreeSection.tree.openContextMenuAndSelect(treeTestEvent, constants.dropEvent);
            await Workbench.pushDialogButton(`Drop ${testEvent}`);
            await Workbench.getNotification(`The object ${testEvent} has been dropped successfully.`);
            await driver.wait(dbTreeSection.tree.untilDoesNotExist(testEvent), constants.wait5seconds);

        });

    });

});
