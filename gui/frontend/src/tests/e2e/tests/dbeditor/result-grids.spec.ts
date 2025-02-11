/*
 * Copyright (c) 2024, Oracle and/or its affiliates.
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
 * MERCHANTABILITY or itNESS FOR A PARTICULAR PURPOSE.  See
 * the GNU General Public License, version 2.0, for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 */

import { basename } from "path";
import { Key, until } from "selenium-webdriver";
import { DatabaseConnectionOverview } from "../../lib/databaseConnectionOverview.js";
import { Misc } from "../../lib/misc.js";
import * as locator from "../../lib/locators.js";
import * as interfaces from "../../lib/interfaces.js";
import * as constants from "../../lib/constants.js";
import { driver, loadDriver } from "../../lib/driver.js";
import { Os } from "../../lib/os.js";
import { E2ENotebook } from "../../lib/E2ENotebook.js";
import { E2EScript } from "../../lib/E2EScript.js";
import { E2EToastNotification } from "../../lib/E2EToastNotification.js";

const filename = basename(__filename);
const url = Misc.getUrl(basename(filename));

const globalConn: interfaces.IDBConnection = {
    dbType: "MySQL",
    caption: `connResultGrids`,
    description: "Local connection",
    basic: {
        hostname: String(process.env.DBHOSTNAME),
        protocol: "mysql",
        username: String(process.env.DBUSERNAME3),
        port: parseInt(process.env.DBPORT!, 10),
        portX: parseInt(process.env.DBPORTX!, 10),
        schema: "sakila",
        password: String(process.env.DBUSERNAME3PWD),
    },
};

describe("Result grids", () => {

    const notebook = new E2ENotebook();
    let testFailed = false;
    let cleanEditor = false;

    beforeAll(async () => {
        await loadDriver();
        await driver.get(url);

        try {
            await driver.wait(Misc.untilHomePageIsLoaded(), constants.wait10seconds, "Home page was not loaded");
            await driver.executeScript("arguments[0].click()", await driver.findElement(locator.sqlEditorPage.icon));
            await DatabaseConnectionOverview.createDataBaseConnection(globalConn);
            const dbConnection = await DatabaseConnectionOverview.getConnection(globalConn.caption!);
            await driver.actions().move({ origin: dbConnection }).perform();
            await driver.executeScript("arguments[0].click()", dbConnection);
            await driver.wait(new E2ENotebook().untilIsOpened(globalConn), constants.wait10seconds);
            await notebook.codeEditor.loadCommandResults();
        } catch (e) {
            await Misc.storeScreenShot("beforeAll_Notebook");
            throw e;
        }
    });

    afterAll(async () => {
        await Os.writeFELogs(basename(__filename), driver.manage().logs());
        await driver.close();
        await driver.quit();
    });

    describe("MySQL", () => {

        testFailed = false;

        afterEach(async () => {
            if (testFailed) {
                testFailed = false;
                await Misc.storeScreenShot();
            }
            if (cleanEditor) {
                await notebook.codeEditor.clean();
                cleanEditor = false;
            }
        });

        it("Result grid context menu - Capitalize, Convert to lower, upper case and mark for deletion", async () => {
            try {
                await notebook.codeEditor.clean();

                // AVOID FLAKY FAILURE, SOMETIMES THE FIRST QUERY DOES NOT RETURN ANY RESULTS
                let result: interfaces.ICommandResult;
                await driver.wait(async () => {
                    try {
                        result = await notebook.codeEditor.execute("select * from sakila.result_sets;", true);

                        return true;
                    } catch (e) {
                        await notebook.codeEditor.clean();
                    }
                }, constants.wait10seconds, "Query did not generated any result after 10secs");
                // ----------------

                result = result!;
                expect(result.toolbar!.status).toMatch(/OK/);
                const rowNumber = 0;
                const rowColumn = "text_field";

                const originalCellValue = await result.grid!.getCellValue(rowNumber, rowColumn);
                await result.grid!.openCellContextMenuAndSelect(0, rowColumn,
                    constants.resultGridContextMenu.capitalizeText);
                await driver.wait(result.grid!.untilCellsWereChanged(1), constants.wait5seconds);

                const capitalizedCellValue = await result.grid!.getCellValue(rowNumber, rowColumn);
                expect(capitalizedCellValue).toBe(`${originalCellValue.charAt(0)
                    .toUpperCase()}${originalCellValue.slice(1)}`);

                await result.grid!.openCellContextMenuAndSelect(0, rowColumn,
                    constants.resultGridContextMenu.convertTextToLowerCase);

                const lowerCaseCellValue = await result.grid!.getCellValue(rowNumber, rowColumn);
                expect(lowerCaseCellValue).toBe(capitalizedCellValue.toLowerCase());

                await result.grid!.openCellContextMenuAndSelect(0, rowColumn,
                    constants.resultGridContextMenu.convertTextToUpperCase);

                const upperCaseCellValue = await result.grid!.getCellValue(rowNumber, rowColumn);
                expect(upperCaseCellValue).toBe(lowerCaseCellValue.toUpperCase());

                await result.grid!.openCellContextMenuAndSelect(0, rowColumn,
                    constants.resultGridContextMenu.toggleForDeletion);
                await driver.wait(result.grid!.untilRowIsMarkedForDeletion(rowNumber), constants.wait5seconds);
                await result.toolbar!.rollbackChanges();
            } catch (e) {
                testFailed = true;
                throw e;
            }

        });

        it("Verify mysql data types - integer columns", async () => {
            try {
                await notebook.codeEditor.clean();
                const result = await notebook.codeEditor.execute("SELECT * from sakila.all_data_types_ints;");
                expect(result.toolbar!.status).toMatch(/OK/);
                const row = 0;
                const smallIntField = await result.grid!.getCellValue(row, "test_smallint");
                const mediumIntField = await result.grid!.getCellValue(row, "test_mediumint");
                const intField = await result.grid!.getCellValue(row, "test_integer");
                const bigIntField = await result.grid!.getCellValue(row, "test_bigint");
                const decimalField = await result.grid!.getCellValue(row, "test_decimal");
                const floatFIeld = await result.grid!.getCellValue(row, "test_float");
                const doubleField = await result.grid!.getCellValue(row, "test_double");
                const booleanCell = await result.grid!.getCellValue(row, "test_boolean");

                expect(smallIntField).toMatch(/(\d+)/);
                expect(mediumIntField).toMatch(/(\d+)/);
                expect(intField).toMatch(/(\d+)/);
                expect(bigIntField).toMatch(/(\d+)/);
                expect(decimalField).toMatch(/(\d+).(\d+)/);
                expect(floatFIeld).toMatch(/(\d+).(\d+)/);
                expect(doubleField).toMatch(/(\d+).(\d+)/);
                expect(booleanCell).toMatch(/(true|false)/);
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Verify mysql data types - date columns", async () => {
            try {
                const result = await notebook.codeEditor.execute("SELECT * from sakila.all_data_types_dates;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const row = 0;
                const dateField = await result.grid!.getCellValue(row, "test_date");
                const dateTimeField = await result.grid!.getCellValue(row, "test_datetime");
                const timeStampField = await result.grid!.getCellValue(row, "test_timestamp");
                const timeField = await result.grid!.getCellValue(row, "test_time");
                const yearField = await result.grid!.getCellValue(row, "test_year");

                expect(dateField).toMatch(/(\d+)\/(\d+)\/(\d+)/);
                expect(dateTimeField).toMatch(/(\d+)\/(\d+)\/(\d+)/);
                expect(timeStampField).toMatch(/(\d+)\/(\d+)\/(\d+)/);
                expect(timeField).toMatch(/(\d+):(\d+):(\d+)/);
                expect(yearField).toMatch(/(\d+)/);
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Verify mysql data types - char columns", async () => {
            try {
                const result = await notebook.codeEditor.execute("SELECT * from sakila.all_data_types_chars;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const row = 0;
                const charField = await result.grid!.getCellValue(row, "test_char");
                const varCharField = await result.grid!.getCellValue(row, "test_varchar");
                const tinyTextField = await result.grid!.getCellValue(row, "test_tinytext");
                const textField = await result.grid!.getCellValue(row, "test_text");
                const mediumTextField = await result.grid!.getCellValue(row, "test_mediumtext");
                const longTextField = await result.grid!.getCellValue(row, "test_longtext");
                const enumField = await result.grid!.getCellValue(row, "test_enum");
                const setFIeld = await result.grid!.getCellValue(row, "test_set");
                const jsonField = await result.grid!.getCellValue(row, "test_json");

                expect(charField).toMatch(/([a-z]|[A-Z])/);
                expect(varCharField).toMatch(/([a-z]|[A-Z])/);
                expect(tinyTextField).toMatch(/([a-z]|[A-Z])/);
                expect(textField).toMatch(/([a-z]|[A-Z])/);
                expect(mediumTextField).toMatch(/([a-z]|[A-Z])/);
                expect(longTextField).toMatch(/([a-z]|[A-Z])/);
                expect(enumField).toMatch(/([a-z]|[A-Z])/);
                expect(setFIeld).toMatch(/([a-z]|[A-Z])/);
                expect(jsonField).toMatch(/\{.*\}/);
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Verify mysql data types - blob columns", async () => {
            try {
                const result = await notebook.codeEditor.execute("SELECT * from sakila.all_data_types_blobs;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const row = 0;
                const binaryField = await result.grid!.getCellValue(row, "test_binary");
                const varBinaryField = await result.grid!.getCellValue(row, "test_varbinary");

                expect(await result.grid!.getCellIconType(row, "test_tinyblob")).toBe(constants.blob);
                expect(await result.grid!.getCellIconType(row, "test_blob")).toBe(constants.blob);
                expect(await result.grid!.getCellIconType(row, "test_mediumblob")).toBe(constants.blob);
                expect(await result.grid!.getCellIconType(row, "test_longblob")).toBe(constants.blob);
                expect(binaryField).toMatch(/0x/);
                expect(varBinaryField).toMatch(/0x/);
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Verify mysql data types - geometry columns", async () => {
            try {
                const result = await notebook.codeEditor.execute("SELECT * from sakila.all_data_types_geometries;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const row = 0;
                const bitCell = await result.grid!.getCellValue(row, "test_bit");
                expect(await result.grid!.getCellIconType(row, "test_point")).toBe(constants.geometry);
                expect(await result.grid!.getCellIconType(row, "test_linestring")).toBe(constants.geometry);
                expect(await result.grid!.getCellIconType(row, "test_polygon")).toBe(constants.geometry);
                expect(await result.grid!.getCellIconType(row, "test_multipoint")).toBe(constants.geometry);
                expect(await result.grid!.getCellIconType(row, "test_multilinestring")).toBe(constants.geometry);
                expect(await result.grid!.getCellIconType(row, "test_multipolygon")).toBe(constants.geometry);
                expect(await result.grid!.getCellIconType(row, "test_geometrycollection")).toBe(constants.geometry);
                expect(bitCell).toMatch(/(\d+)/);
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Select a Result Grid View", async () => {
            try {
                const result = await notebook.codeEditor.execute("select * from sakila.actor;");
                expect(result.toolbar!.status).toMatch(/OK/);
                await result.grid!.editCells([{
                    rowNumber: 0,
                    columnName: "first_name",
                    value: "changed",
                }], constants.doubleClick);

                await result.toolbar!.selectView(constants.previewView);
                expect(result.preview).toBeDefined();
                await result.toolbar!.selectView(constants.gridView);
                expect(result.preview).toBeUndefined();
                expect(result.grid).toBeDefined();
                await result.toolbar?.rollbackChanges();
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Edit a result grid using the keyboard", async () => {
            try {
                await notebook.codeEditor.clean();
                const result = await notebook.codeEditor.execute("select * from sakila.result_sets;");
                expect(result.toolbar!.status).toMatch(/OK/);

                await result.grid?.startFocus();
                await result.grid!.editCells([
                    { rowNumber: 0, columnName: "text_field", value: "edited" },
                ], constants.pressEnter);

                const refKey = Os.isMacOs() ? Key.COMMAND : Key.META;

                await driver.actions()
                    .keyDown(refKey)
                    .keyDown(Key.ALT)
                    .pause(300)
                    .keyDown(Key.ENTER)
                    .keyUp(Key.ENTER)
                    .keyUp(refKey)
                    .keyUp(Key.ALT)
                    .perform();

                const notification = await new E2EToastNotification().create();
                expect(notification.message).toBe("Changes committed successfully.");
                await notification.close();

                await result.grid?.startFocus();
                await result.grid!.editCells([
                    { rowNumber: 0, columnName: "int_field", value: "25" },
                ], constants.pressEnter);

                const textArea = await driver.findElement(locator.notebook.codeEditor.textArea);
                await textArea.sendKeys(Key.chord(refKey, Key.ESCAPE));

                const confirmDialog = await driver.wait(Misc.untilConfirmationDialogExists("for rollback"));
                await confirmDialog!.findElement(locator.confirmDialog.accept).click();

            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Edit a result grid using the Start Editing button", async () => {
            try {
                await notebook.codeEditor.clean();
                const result = await notebook.codeEditor.execute("select * from sakila.result_sets;");
                expect(result.toolbar!.status).toMatch(/OK/);

                await result.grid!.editCells([
                    { rowNumber: 0, columnName: "text_field", value: "other edited" },
                    { rowNumber: 0, columnName: "int_field", value: "30" },
                ], constants.editButton);

                const refKey = Os.isMacOs() ? Key.COMMAND : Key.META;

                await driver.actions()
                    .keyDown(refKey)
                    .keyDown(Key.ALT)
                    .pause(300)
                    .keyDown(Key.ENTER)
                    .keyUp(Key.ENTER)
                    .keyUp(refKey)
                    .keyUp(Key.ALT)
                    .perform();

                const notification = await new E2EToastNotification().create();
                expect(notification.message).toBe("Changes committed successfully.");
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Edit a result grid, verify query preview and commit - integer columns", async () => {
            try {
                const result = await notebook.codeEditor.execute("select * from sakila.all_data_types_ints;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const booleanEdited = false;
                const smallIntEdited = "32761";
                const mediumIntEdited = "8388601";
                const intEdited = "1201";
                const bigIntEdited = "4294967291";
                const decimalEdited = "1.12345";
                const floatEdited = "10.767";
                const doubleEdited = "5.72";

                const rowToEdit = 0;
                const cellsToEdit: interfaces.IResultGridCell[] = [
                    { rowNumber: rowToEdit, columnName: "test_smallint", value: smallIntEdited },
                    { rowNumber: rowToEdit, columnName: "test_mediumint", value: mediumIntEdited },
                    { rowNumber: rowToEdit, columnName: "test_integer", value: intEdited },
                    { rowNumber: rowToEdit, columnName: "test_bigint", value: bigIntEdited },
                    { rowNumber: rowToEdit, columnName: "test_decimal", value: decimalEdited },
                    { rowNumber: rowToEdit, columnName: "test_float", value: floatEdited },
                    { rowNumber: rowToEdit, columnName: "test_double", value: doubleEdited },
                    { rowNumber: rowToEdit, columnName: "test_boolean", value: booleanEdited },
                ];

                await result.grid!.editCells(cellsToEdit, constants.doubleClick);
                const booleanField = booleanEdited ? 1 : 0;
                const expectedSqlPreview = [
                    /UPDATE sakila.all_data_types_ints SET/,
                    new RegExp(`test_smallint = ${smallIntEdited}`),
                    new RegExp(`test_mediumint = ${mediumIntEdited}`),
                    new RegExp(`test_integer = ${intEdited}`),
                    new RegExp(`test_bigint = ${bigIntEdited}`),
                    new RegExp(`test_decimal = ${decimalEdited}`),
                    new RegExp(`test_float = ${floatEdited}`),
                    new RegExp(`test_double = ${doubleEdited}`),
                    new RegExp(`test_boolean = ${booleanField}`),
                    /WHERE id = 1;/,
                ];

                await result.toolbar!.selectSqlPreview();
                for (let i = 0; i <= expectedSqlPreview.length - 1; i++) {
                    expect(result.preview!.text).toMatch(expectedSqlPreview[i]);
                }

                await result.clickSqlPreviewContent();
                await driver.wait(result.grid!.untilRowIsHighlighted(rowToEdit), constants.wait5seconds);

                await result.toolbar!.applyChanges();
                await driver.wait(result.toolbar!.untilStatusMatches(/(\d+).*updated/), constants.wait5seconds);

                const result1 = await notebook.codeEditor
                    .execute("select * from sakila.all_data_types_ints where id = 1;");
                expect(result1.toolbar!.status).toMatch(/OK/);
                const testBoolean = await result1.grid!.getCellValue(rowToEdit, "test_boolean");
                expect(testBoolean).toBe(booleanEdited.toString());
                const testSmallInt = await result1.grid!.getCellValue(rowToEdit, "test_smallint");
                expect(testSmallInt).toBe(smallIntEdited);
                const testMediumInt = await result1.grid!.getCellValue(rowToEdit, "test_mediumint");
                expect(testMediumInt).toBe(mediumIntEdited);
                const testInteger = await result1.grid!.getCellValue(rowToEdit, "test_integer");
                expect(testInteger).toBe(intEdited);
                const testBigInt = await result1.grid!.getCellValue(rowToEdit, "test_bigint");
                expect(testBigInt).toBe(bigIntEdited);
                const testDecimal = await result1.grid!.getCellValue(rowToEdit, "test_decimal");
                expect(testDecimal).toBe(decimalEdited);
                const testFloat = await result1.grid!.getCellValue(rowToEdit, "test_float");
                expect(testFloat).toBe(floatEdited);
                const testDouble = await result1.grid!.getCellValue(rowToEdit, "test_double");
                expect(testDouble).toBe(doubleEdited);
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Edit a result grid, verify query preview and commit - date columns", async () => {
            try {
                await notebook.codeEditor.clean();
                const result = await notebook.codeEditor.execute("select * from sakila.all_data_types_dates;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const dateEdited = "2024-01-01";
                const dateTimeEdited = "2024-01-01 15:00";
                const timeStampEdited = "2024-01-01 15:00";
                const timeEdited = "23:59";
                const yearEdited = "2030";

                const rowToEdit = 0;
                const cellsToEdit: interfaces.IResultGridCell[] = [
                    { rowNumber: rowToEdit, columnName: "test_date", value: dateEdited },
                    { rowNumber: rowToEdit, columnName: "test_datetime", value: dateTimeEdited },
                    { rowNumber: rowToEdit, columnName: "test_timestamp", value: timeStampEdited },
                    { rowNumber: rowToEdit, columnName: "test_time", value: timeEdited },
                    { rowNumber: rowToEdit, columnName: "test_year", value: yearEdited },
                ];
                await result.grid!.editCells(cellsToEdit, constants.doubleClick);
                const dateTimeToISO = Misc.convertDateToISO(dateTimeEdited);
                const timeStampToISO = Misc.convertDateToISO(timeStampEdited);
                const timeTransformed = Misc.convertTimeTo12H(timeEdited);

                const expectedSqlPreview = [
                    /UPDATE sakila.all_data_types_dates SET/,
                    new RegExp(`test_date = '${dateEdited}'`),
                    new RegExp(`test_datetime = '(${dateTimeEdited}:00|${dateTimeToISO}:00)'`),
                    new RegExp(`test_timestamp = '(${timeStampEdited}:00|${timeStampToISO}:00)'`),
                    new RegExp(`test_time = '(${timeEdited}|${timeTransformed})'`),
                    new RegExp(`test_year = ${yearEdited}`),
                    /WHERE id = 1;/,
                ];

                await result.toolbar!.selectSqlPreview();
                for (let i = 0; i <= expectedSqlPreview.length - 1; i++) {
                    expect(result.preview!.text).toMatch(expectedSqlPreview[i]);
                }

                await result.clickSqlPreviewContent();
                await driver.wait(result.grid!.untilRowIsHighlighted(rowToEdit), constants.wait5seconds);
                await result.toolbar!.applyChanges();
                await driver.wait(result.toolbar!.untilStatusMatches(/(\d+).*updated/), constants.wait5seconds);

                const result1 = await notebook.codeEditor
                    .execute("select * from sakila.all_data_types_dates where id = 1;");
                expect(result1.toolbar!.status).toMatch(/OK/);

                const testDate = await result1.grid!.getCellValue(rowToEdit, "test_date");
                expect(testDate).toBe("01/01/2024");
                const testDateTime = await result1.grid!.getCellValue(rowToEdit, "test_datetime");
                expect(testDateTime).toBe("01/01/2024");
                const testTimeStamp = await result1.grid!.getCellValue(rowToEdit, "test_timestamp");
                expect(testTimeStamp).toBe("01/01/2024");
                const testTime = await result1.grid!.getCellValue(rowToEdit, "test_time");
                const convertedTime = Misc.convertTimeTo12H(timeEdited);
                expect(testTime === `${timeEdited}:00` || testTime === convertedTime).toBe(true);
                const testYear = await result1.grid!.getCellValue(rowToEdit, "test_year");
                expect(testYear).toBe(yearEdited);
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Edit a result grid, verify query preview and commit - char columns", async () => {
            try {
                await notebook.codeEditor.clean();
                const result = await notebook.codeEditor
                    .execute("select * from sakila.all_data_types_chars where id = 2;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const charEdited = "test_char_edited";
                const varCharEdited = "test_varchar_edited";
                const tinyTextEdited = "test_tiny_edited";
                const textEdited = "test_text_edited";
                const textMediumEdited = "test_med_edited";
                const longTextEdited = "test_long_edited";
                const enumEdited = "value2_dummy_dummy_dummy";
                const setEdited = "value2_dummy_dummy_dummy";
                const jsonEdited = '{"test": "2"}';

                const rowToEdit = 0;
                const cellsToEdit: interfaces.IResultGridCell[] = [
                    { rowNumber: rowToEdit, columnName: "test_char", value: charEdited },
                    { rowNumber: rowToEdit, columnName: "test_varchar", value: varCharEdited },
                    { rowNumber: rowToEdit, columnName: "test_tinytext", value: tinyTextEdited },
                    { rowNumber: rowToEdit, columnName: "test_text", value: textEdited },
                    { rowNumber: rowToEdit, columnName: "test_mediumtext", value: textMediumEdited },
                    { rowNumber: rowToEdit, columnName: "test_longtext", value: longTextEdited },
                    { rowNumber: rowToEdit, columnName: "test_enum", value: enumEdited },
                    { rowNumber: rowToEdit, columnName: "test_set", value: setEdited },
                    { rowNumber: rowToEdit, columnName: "test_json", value: jsonEdited },
                ];
                await result.grid!.editCells(cellsToEdit, constants.doubleClick);

                const expectedSqlPreview = [
                    /UPDATE sakila.all_data_types_chars SET/,
                    new RegExp(`test_char = '${charEdited}'`),
                    new RegExp(`test_varchar = '${varCharEdited}'`),
                    new RegExp(`test_tinytext = '${tinyTextEdited}'`),
                    new RegExp(`test_text = '${textEdited}'`),
                    new RegExp(`test_mediumtext = '${textMediumEdited}'`),
                    new RegExp(`test_longtext = '${longTextEdited}'`),
                    new RegExp(`test_enum = '${enumEdited}'`),
                    new RegExp(`test_set = '${setEdited}'`),
                    Misc.transformToMatch(`test_json = '${jsonEdited}'`),
                    /WHERE id = 2;/,
                ];

                await result.toolbar!.selectSqlPreview();
                for (let i = 0; i <= expectedSqlPreview.length - 1; i++) {
                    expect(result.preview!.text).toMatch(expectedSqlPreview[i]);
                }

                await result.clickSqlPreviewContent();
                await driver.wait(result.grid!.untilRowIsHighlighted(rowToEdit), constants.wait5seconds);
                await result.toolbar!.applyChanges();
                await driver.wait(result.toolbar!.untilStatusMatches(/(\d+).*updated/), constants.wait5seconds);

                const result1 = await notebook.codeEditor
                    .execute("select * from sakila.all_data_types_chars where id = 2;");
                expect(result1.toolbar!.status).toMatch(/OK/);
                const testChar = await result1.grid!.getCellValue(rowToEdit, "test_char");
                expect(testChar).toBe(charEdited);
                const testVarChar = await result1.grid!.getCellValue(rowToEdit, "test_varchar");
                expect(testVarChar).toBe(varCharEdited);
                const testTinyText = await result1.grid!.getCellValue(rowToEdit, "test_tinytext");
                expect(testTinyText).toBe(tinyTextEdited);
                const testText = await result1.grid!.getCellValue(rowToEdit, "test_text");
                expect(testText).toBe(textEdited);
                const testMediumText = await result1.grid!.getCellValue(rowToEdit, "test_mediumtext");
                expect(testMediumText).toBe(textMediumEdited);
                const testLongText = await result1.grid!.getCellValue(rowToEdit, "test_longtext");
                expect(testLongText).toBe(longTextEdited);
                const testEnum = await result1.grid!.getCellValue(rowToEdit, "test_enum");
                expect(testEnum).toBe(enumEdited);
                const testSet = await result1.grid!.getCellValue(rowToEdit, "test_set");
                expect(testSet).toBe(setEdited);
                const testJson = await result1.grid!.getCellValue(rowToEdit, "test_json");
                expect(testJson).toBe(jsonEdited);
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Edit a result grid, verify query preview and commit - geometry columns", async () => {
            try {
                await notebook.codeEditor.clean();
                const result = await notebook.codeEditor.execute("select * from sakila.all_data_types_geometries;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const pointEdited = "ST_GeomFromText('POINT(1 2)')";
                const lineStringEdited = "ST_LineStringFromText('LINESTRING(0 0,1 1,2 1)')";
                const polygonEdited = "ST_GeomFromText('POLYGON((0 0,11 0,10 10,0 10,0 0),(5 5,7 5,7 7,5 7, 5 5))')";
                const multiPointEdited = "ST_GeomFromText('MULTIPOINT(0 1, 20 20, 60 60)')";
                const multiLineStrEdited = "ST_GeomFromText('MultiLineString((2 1,2 2,3 3),(4 4,5 5))')";
                const multiPoly = "ST_GeomFromText('MULTIPOLYGON(((0 0,11 0,12 11,0 9,0 0)),((3 5,7 4,4 7,7 7,3 5)))')";
                const geoCollEd = "ST_GeomFromText('GEOMETRYCOLLECTION(POINT(1 2),LINESTRING(0 0,1 1,2 2,3 3,4 4))')";
                const bitEdited = "11111111111111";
                const rowToEdit = 0;

                const cellsToEdit: interfaces.IResultGridCell[] = [
                    { rowNumber: rowToEdit, columnName: "test_point", value: pointEdited },
                    { rowNumber: rowToEdit, columnName: "test_bit", value: bitEdited },
                    { rowNumber: rowToEdit, columnName: "test_linestring", value: lineStringEdited },
                    { rowNumber: rowToEdit, columnName: "test_polygon", value: polygonEdited },
                    { rowNumber: rowToEdit, columnName: "test_multipoint", value: multiPointEdited },
                    { rowNumber: rowToEdit, columnName: "test_multilinestring", value: multiLineStrEdited },
                    { rowNumber: rowToEdit, columnName: "test_multipolygon", value: multiPoly },
                    { rowNumber: rowToEdit, columnName: "test_geometrycollection", value: geoCollEd },
                ];
                await result.grid!.editCells(cellsToEdit, constants.doubleClick);

                const expectedSqlPreview = [
                    /UPDATE sakila.all_data_types_geometries SET/,
                    new RegExp(`test_bit = b'${bitEdited}'`),
                    Misc.transformToMatch(`test_point = ${pointEdited}`),
                    Misc.transformToMatch(`test_linestring = ${lineStringEdited}`),
                    Misc.transformToMatch(`test_polygon = ${polygonEdited}`),
                    Misc.transformToMatch(`test_multipoint = ${multiPointEdited}`),
                    Misc.transformToMatch(`test_multilinestring = ${multiLineStrEdited}`),
                    Misc.transformToMatch(`test_multipolygon = ${multiPoly}`),
                    Misc.transformToMatch(`test_geometrycollection = ${geoCollEd}`),
                    new RegExp(`WHERE id = 1;`),
                ];

                await result.toolbar!.selectSqlPreview();
                for (let i = 0; i <= expectedSqlPreview.length - 1; i++) {
                    expect(result.preview!.text).toMatch(expectedSqlPreview[i]);
                }

                await result.clickSqlPreviewContent();
                await driver.wait(result.grid!.untilRowIsHighlighted(rowToEdit), constants.wait5seconds);
                await result.toolbar!.applyChanges();
                await driver.wait(result.toolbar!.untilStatusMatches(/(\d+).*updated/), constants.wait5seconds);

                const result1 = await notebook.codeEditor
                    .execute("select * from sakila.all_data_types_geometries where id = 1;");
                expect(result1.toolbar!.status).toMatch(/OK/);

                const testPoint = await result1.grid!.getCellValue(rowToEdit, "test_point");
                expect(testPoint).toBe(constants.geometry);
                const testLineString = await result1.grid!.getCellValue(rowToEdit, "test_linestring");
                expect(testLineString).toBe(constants.geometry);
                const testPolygon = await result1.grid!.getCellValue(rowToEdit, "test_polygon");
                expect(testPolygon).toBe(constants.geometry);
                const testMultiPoint = await result1.grid!.getCellValue(rowToEdit, "test_multipoint");
                expect(testMultiPoint).toBe(constants.geometry);
                const testMultiLineString = await result1.grid!.getCellValue(rowToEdit, "test_multilinestring");
                expect(testMultiLineString).toBe(constants.geometry);
                const testMultiPolygon = await result1.grid!.getCellValue(rowToEdit, "test_multipolygon");
                expect(testMultiPolygon).toBe(constants.geometry);
                const testGeomCollection = await result1.grid!.getCellValue(rowToEdit, "test_geometrycollection");
                expect(testGeomCollection).toBe(constants.geometry);
                const testBit = await result.grid!.getCellValue(rowToEdit, "test_bit");
                expect(testBit).toBe("16383");
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Result grid cell tooltips - integer columns", async () => {
            try {
                const rowNumber = 0;
                const tableColumns: string[] = [];

                await notebook.toolbar.selectEditor(new RegExp(constants.dbNotebook), globalConn.caption);
                await notebook.codeEditor.clean();
                await notebook.codeEditor.execute("\\about");
                const result = await notebook.codeEditor.execute("SELECT * from sakila.all_data_types_ints limit 1;");
                expect(result.toolbar!.status).toMatch(/OK/);

                for (const key of result.grid!.columnsMap!.keys()) {
                    tableColumns.push(key);
                }

                for (let i = 1; i <= tableColumns.length - 1; i++) {
                    if (i === tableColumns.length - 1) {
                        await result.grid!.reduceCellWidth(rowNumber, tableColumns[i], "js");
                    } else {
                        await result.grid!.reduceCellWidth(rowNumber, tableColumns[i]);
                    }
                    const cellText = await result.grid!.getCellValue(rowNumber, tableColumns[i]);
                    await driver.wait(result.grid!.untilCellTooltipIs(rowNumber, tableColumns[i], cellText),
                        constants.wait3seconds);
                }
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Result grid cell tooltips - date columns", async () => {
            try {
                const rowNumber = 0;
                await notebook.codeEditor.clean();
                await notebook.codeEditor.execute("\\about");
                const result = await notebook.codeEditor
                    .execute("SELECT * from sakila.all_data_types_dates where id = 1;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const tableColumns: string[] = [];
                for (const key of result.grid!.columnsMap!.keys()) {
                    tableColumns.push(key);
                }

                for (let i = 1; i <= tableColumns.length - 1; i++) {
                    if (i === tableColumns.length - 1) {
                        await result.grid!.reduceCellWidth(rowNumber, tableColumns[i], "js");
                    } else {
                        await result.grid!.reduceCellWidth(rowNumber, tableColumns[i]);
                    }

                    const cellText = await result.grid!.getCellValue(rowNumber, tableColumns[i]);
                    await driver.wait(result.grid!.untilCellTooltipIs(rowNumber, tableColumns[i], cellText),
                        constants.wait3seconds);
                }
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Result grid cell tooltips - char columns", async () => {
            try {
                const rowNumber = 0;
                await notebook.codeEditor.clean();
                await notebook.codeEditor.execute("\\about");
                const result = await notebook.codeEditor
                    .execute("SELECT * from sakila.all_data_types_chars where id = 1;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const tableColumns: string[] = [];
                for (const key of result.grid!.columnsMap!.keys()) {
                    tableColumns.push(key);
                }

                for (let i = 1; i <= tableColumns.length - 1; i++) {
                    await result.grid!.reduceCellWidth(rowNumber, tableColumns[i]);

                    const cellText = await result.grid!.getCellValue(rowNumber, tableColumns[i]);
                    await driver.wait(result.grid!.untilCellTooltipIs(rowNumber, tableColumns[i], cellText),
                        constants.wait3seconds);
                }
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Result grid cell tooltips - binary and varbinary columns", async () => {
            try {
                const rowNumber = 0;
                await notebook.codeEditor.clean();
                await notebook.codeEditor.execute("\\about");
                const result = await notebook.codeEditor.execute("SELECT * from sakila.all_data_types_blobs limit 1;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const tableColumns: string[] = [];
                for (const key of result.grid!.columnsMap!.keys()) {
                    tableColumns.push(key);
                }

                for (let i = 5; i <= tableColumns.length - 1; i++) {
                    if (i === tableColumns.length - 1) {
                        await result.grid!.reduceCellWidth(rowNumber, tableColumns[i], "js");
                    } else {
                        await result.grid!.reduceCellWidth(rowNumber, tableColumns[i]);
                    }

                    const cellText = await result.grid!.getCellValue(rowNumber, tableColumns[i]);
                    await driver.wait(result.grid!.untilCellTooltipIs(rowNumber, tableColumns[i], cellText),
                        constants.wait3seconds);

                }
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Result grid cell tooltips - bit column", async () => {
            try {
                const rowNumber = 0;
                await notebook.codeEditor.clean();
                await notebook.codeEditor.execute("\\about");
                const result = await notebook.codeEditor
                    .execute("SELECT * from sakila.all_data_types_geometries;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const column = "test_bit";
                await result.grid!.reduceCellWidth(rowNumber, column);
                const cellText = await result.grid!.getCellValue(rowNumber, column);
                await driver.wait(result.grid!.untilCellTooltipIs(rowNumber, column, cellText), constants.wait3seconds);
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Edit a result grid and rollback", async () => {
            try {
                const modifiedText = "56";
                await notebook.codeEditor.clean();
                const result = await notebook.codeEditor.execute("select * from sakila.all_data_types_ints;");
                expect(result.toolbar!.status).toMatch(/OK/);
                await result.grid!.editCells(
                    [{
                        rowNumber: 0,
                        columnName: "test_integer",
                        value: modifiedText,
                    }], constants.doubleClick);

                await result.toolbar!.rollbackChanges();
                expect((await result.grid!.content!.getAttribute("innerHTML"))
                    .match(/rollbackTest/) === null).toBe(true);
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Verify not editable result grids", async () => {
            try {
                const queries = [
                    "select count(address_id) from sakila.address GROUP by city_id having count(address_id) > 0;",
                    `select actor_id FROM sakila.actor INNER JOIN sakila.address 
                        ON actor.actor_id = address.address_id;`,
                    "select first_name from sakila.actor UNION SELECT address_id from sakila.address;",
                    "select actor_id from sakila.actor INTERSECT select address_id from sakila.address;",
                    "select first_name from sakila.actor EXCEPT select address from sakila.address;",
                    "SELECT COUNT(*) FROM DUAL;",
                    `select * from sakila.actor where actor_id =
                                (select address_id from sakila.address where address_id = 1) for update;`,
                    "select (actor_id*2), first_name as calculated from sakila.actor;",
                ];
                await notebook.codeEditor.clean();
                for (const query of queries) {
                    const result = await notebook.codeEditor.execute(query);
                    expect(result.toolbar!.status).toMatch(/OK/);
                    const editBtn = await result.toolbar?.getEditButton();
                    expect(await editBtn!.getAttribute("data-tooltip")).toBe("Data not editable");
                }
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Add new row on result grid - integer columns", async () => {
            try {
                await notebook.codeEditor.clean();
                const result = await notebook.codeEditor.execute("select * from sakila.all_data_types_ints;");
                expect(result.toolbar!.status).toMatch(/OK/);
                const booleanEdited = true;
                const smallIntEdited = "32761";
                const mediumIntEdited = "8388601";
                const intEdited = "3";
                const bigIntEdited = "4294967291";
                const decimalEdited = "1.12345";
                const floatEdited = "10.767";
                const doubleEdited = "5.72";

                const rowToAdd: interfaces.IResultGridCell[] = [
                    { columnName: "test_smallint", value: smallIntEdited },
                    { columnName: "test_mediumint", value: mediumIntEdited },
                    { columnName: "test_integer", value: intEdited },
                    { columnName: "test_bigint", value: bigIntEdited },
                    { columnName: "test_decimal", value: decimalEdited },
                    { columnName: "test_float", value: floatEdited },
                    { columnName: "test_double", value: doubleEdited },
                    { columnName: "test_boolean", value: booleanEdited },
                ];

                await result.grid!.addRow(rowToAdd);
                await result.toolbar!.applyChanges();

                await driver.wait(result.toolbar!.untilStatusMatches(/(\d+).*updated/), constants.wait5seconds);
                const result1 = await notebook.codeEditor
                    // eslint-disable-next-line max-len
                    .execute("select * from sakila.all_data_types_ints where id = (select max(id) from sakila.all_data_types_ints);");
                expect(result1.toolbar!.status).toMatch(/OK/);

                const row = 0;

                const testBoolean = await result1.grid!.getCellValue(row, "test_boolean");
                expect(testBoolean).toBe(booleanEdited.toString());
                const testSmallInt = await result1.grid!.getCellValue(row, "test_smallint");
                expect(testSmallInt).toBe(smallIntEdited);
                const testMediumInt = await result1.grid!.getCellValue(row, "test_mediumint");
                expect(testMediumInt).toBe(mediumIntEdited);
                const testInteger = await result1.grid!.getCellValue(row, "test_integer");
                expect(testInteger).toBe(intEdited);
                const testBigInt = await result1.grid!.getCellValue(row, "test_bigint");
                expect(testBigInt).toBe(bigIntEdited);
                const testDecimal = await result1.grid!.getCellValue(row, "test_decimal");
                expect(testDecimal).toBe(decimalEdited);
                const testFloat = await result1.grid!.getCellValue(row, "test_float");
                expect(testFloat).toBe(floatEdited);
                const testDouble = await result1.grid!.getCellValue(row, "test_double");
                expect(testDouble).toBe(doubleEdited);
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Add new row on result grid - date columns", async () => {
            try {
                await notebook.codeEditor.clean();
                const result = await notebook.codeEditor.execute("select * from sakila.all_data_types_dates;");
                expect(result.toolbar!.status).toMatch(/OK/);
                const dateEdited = "2024-01-01";
                const dateTimeEdited = "2024-01-01 15:00";
                const timeStampEdited = "2024-01-01 15:00";
                const timeEdited = "23:59";
                const yearEdited = "2024";

                const rowToAdd: interfaces.IResultGridCell[] = [
                    { columnName: "test_date", value: dateEdited },
                    { columnName: "test_datetime", value: dateTimeEdited },
                    { columnName: "test_timestamp", value: timeStampEdited },
                    { columnName: "test_time", value: timeEdited },
                    { columnName: "test_year", value: yearEdited },
                ];

                await result.grid!.addRow(rowToAdd);
                await result.toolbar!.applyChanges();
                await driver.wait(result.toolbar!.untilStatusMatches(/(\d+).*updated/), constants.wait5seconds);

                const result1 = await notebook.codeEditor
                    // eslint-disable-next-line max-len
                    .execute("select * from sakila.all_data_types_dates where id = (select max(id) from sakila.all_data_types_dates);");
                expect(result1.toolbar!.status).toMatch(/OK/);
                const row = 0;
                const testDate = await result1.grid!.getCellValue(row, "test_date");
                expect(testDate).toBe("01/01/2024");
                const testDateTime = await result1.grid!.getCellValue(row, "test_datetime");
                expect(testDateTime).toBe("01/01/2024");
                const testTimeStamp = await result1.grid!.getCellValue(row, "test_timestamp");
                expect(testTimeStamp).toBe("01/01/2024");
                const testTime = await result1.grid!.getCellValue(row, "test_time");
                const convertedTime = Misc.convertTimeTo12H(timeEdited);
                expect(testTime === `${timeEdited}:00` || testTime === convertedTime).toBe(true);
                const testYear = await result1.grid!.getCellValue(row, "test_year");
                expect(testYear).toBe(yearEdited);
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Add new row on result grid - char columns", async () => {
            try {
                await notebook.codeEditor.clean();
                const result = await notebook.codeEditor.execute("select * from sakila.all_data_types_chars;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const charEdited = "test_char_edited";
                const varCharEdited = "test_varchar_edited";
                const tinyTextEdited = "test_tiny_edited";
                const textEdited = "test_text_edited";
                const textMediumEdited = "test_med_edited";
                const longTextEdited = "test_long_edited";
                const enumEdited = "value4_dummy_dummy_dummy";
                const setEdited = "value4_dummy_dummy_dummy";
                const jsonEdited = '{"test": "2"}';

                const rowToAdd: interfaces.IResultGridCell[] = [
                    { columnName: "test_char", value: charEdited },
                    { columnName: "test_varchar", value: varCharEdited },
                    { columnName: "test_tinytext", value: tinyTextEdited },
                    { columnName: "test_text", value: textEdited },
                    { columnName: "test_mediumtext", value: textMediumEdited },
                    { columnName: "test_longtext", value: longTextEdited },
                    { columnName: "test_enum", value: enumEdited },
                    { columnName: "test_set", value: setEdited },
                    { columnName: "test_json", value: jsonEdited },
                ];

                await result.grid!.addRow(rowToAdd);
                await result.toolbar!.applyChanges();

                await driver.wait(result.toolbar!.untilStatusMatches(/(\d+).*updated/), constants.wait5seconds);
                const result1 = await notebook.codeEditor
                    // eslint-disable-next-line max-len
                    .execute("select * from sakila.all_data_types_chars where id = (select max(id) from sakila.all_data_types_chars);");
                expect(result1.toolbar!.status).toMatch(/OK/);

                const row = 0;
                const testChar = await result1.grid!.getCellValue(row, "test_char");
                expect(testChar).toBe(charEdited);
                const testVarChar = await result1.grid!.getCellValue(row, "test_varchar");
                expect(testVarChar).toBe(varCharEdited);
                const testTinyText = await result1.grid!.getCellValue(row, "test_tinytext");
                expect(testTinyText).toBe(tinyTextEdited);
                const testText = await result1.grid!.getCellValue(row, "test_text");
                expect(testText).toBe(textEdited);
                const testMediumText = await result1.grid!.getCellValue(row, "test_mediumtext");
                expect(testMediumText).toBe(textMediumEdited);
                const testLongText = await result1.grid!.getCellValue(row, "test_longtext");
                expect(testLongText).toBe(longTextEdited);
                const testEnum = await result1.grid!.getCellValue(row, "test_enum");
                expect(testEnum).toBe(enumEdited);
                const testSet = await result1.grid!.getCellValue(row, "test_set");
                expect(testSet).toBe(setEdited);
                const testJson = await result1.grid!.getCellValue(row, "test_json");
                expect(testJson).toBe(jsonEdited);
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Add new row on result grid - geometry columns", async () => {
            try {
                await notebook.codeEditor.clean();
                let result = await notebook.codeEditor.execute("select * from sakila.all_data_types_geometries;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const pointEdited = "ST_GeomFromText('POINT(1 2)')";
                const lineStringEdited = "ST_LineStringFromText('LINESTRING(0 0,1 1,2 1)')";
                const polygonEdited = "ST_GeomFromText('POLYGON((0 0,11 0,10 10,0 10,0 0),(5 5,7 5,7 7,5 7, 5 5))')";
                const multiPointEdited = "ST_GeomFromText('MULTIPOINT(0 1, 20 20, 60 60)')";
                const multiLineStrEdited = "ST_GeomFromText('MultiLineString((2 1,2 2,3 3),(4 4,5 5))')";
                let multiPolyEd = "ST_GeomFromText('MULTIPOLYGON(((";
                multiPolyEd += "0 0,11 0,12 11,0 9,0 0)),((3 5,7 4,4 7,7 7,3 5)))')";
                let geoCollEdited = "ST_GeomFromText('GEOMETRYCOLLECTION(POINT(1 2),LINESTRING(";
                geoCollEdited += "0 0,1 1,2 2,3 3,4 4))')";
                const bitEdited = "11111011111111";

                const rowToAdd: interfaces.IResultGridCell[] = [
                    { columnName: "test_bit", value: bitEdited },
                    { columnName: "test_point", value: pointEdited },
                    { columnName: "test_linestring", value: lineStringEdited },
                    { columnName: "test_polygon", value: polygonEdited },
                    { columnName: "test_multipoint", value: multiPointEdited },
                    { columnName: "test_multilinestring", value: multiLineStrEdited },
                    { columnName: "test_multipolygon", value: multiPolyEd },
                    { columnName: "test_geometrycollection", value: geoCollEdited },
                ];

                await result.grid!.addRow(rowToAdd);
                await result.toolbar!.applyChanges();

                await driver.wait(result.toolbar!.untilStatusMatches(/(\d+).*updated/), constants.wait5seconds);
                result = await notebook.codeEditor
                    // eslint-disable-next-line max-len
                    .execute("select * from sakila.all_data_types_geometries where id = (select max(id) from sakila.all_data_types_geometries);");
                expect(result.toolbar!.status).toMatch(/OK/);
                const row = 0;
                const testPoint = await result.grid!.getCellValue(row, "test_point");
                expect(testPoint).toBe(constants.geometry);
                const testLineString = await result.grid!.getCellValue(row, "test_linestring");
                expect(testLineString).toBe(constants.geometry);
                const testPolygon = await result.grid!.getCellValue(row, "test_polygon");
                expect(testPolygon).toBe(constants.geometry);
                const testMultiPoint = await result.grid!.getCellValue(row, "test_multipoint");
                expect(testMultiPoint).toBe(constants.geometry);
                const testMultiLineString = await result.grid!.getCellValue(row, "test_multilinestring");
                expect(testMultiLineString).toBe(constants.geometry);
                const testMultiPolygon = await result.grid!.getCellValue(row, "test_multipolygon");
                expect(testMultiPolygon).toBe(constants.geometry);
                const testGeomCollection = await result.grid!.getCellValue(row, "test_geometrycollection");
                expect(testGeomCollection).toBe(constants.geometry);
                const testBit = await result.grid!.getCellValue(row, "test_bit");
                expect(testBit).toBe("16127");
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Close a result set", async () => {
            try {
                await notebook.codeEditor.clean();
                const result = await notebook.codeEditor.execute("select * from sakila.actor limit 1;");
                expect(result.toolbar!.status).toMatch(/OK/);

                const id = result.id;
                await result.toolbar!.closeResultSet();

                await driver.wait(async () => {
                    return (await driver.findElements(locator.notebook.codeEditor.editor.result.existsById(id!)))
                        .length === 0;
                }, constants.wait5seconds, `The result set was not closed`);
                await notebook.codeEditor.clean();
            } catch (e) {
                testFailed = true;
                throw e;
            }
        });

        it("Unsaved changes dialog on result grid", async () => {
            try {
                let toMatch = "is currently being edited, do you want to ";
                toMatch += "commit or rollback the changes before continuing";
                const script = await notebook.explorer.addScript("TS");
                await new E2EScript().codeEditor.execute("Math.random()");
                await notebook.toolbar.selectEditor(new RegExp(constants.dbNotebook));

                await notebook.codeEditor.clean();
                const result = await notebook.codeEditor.execute("select * from sakila.result_sets");
                expect(result.toolbar!.status).toMatch(/OK/);
                const cellsToEdit: interfaces.IResultGridCell[] = [{
                    rowNumber: 0,
                    columnName: "text_field",
                    value: "ping",
                }];

                await result.grid!.editCells(cellsToEdit, constants.doubleClick);
                await (await notebook.explorer.getMySQLAdminElement(constants.serverStatus)).click();
                let dialog = await driver.wait(Misc.untilConfirmationDialogExists(
                    " after switching to Server Status page")
                    , constants.wait5seconds);
                expect(await (await dialog!.findElement(locator.confirmDialog.message))
                    .getText())
                    .toMatch(new RegExp(toMatch));
                await dialog!.findElement(locator.confirmDialog.cancel).click();
                expect((await notebook.toolbar.getCurrentEditor())?.label).toBe(constants.dbNotebook);

                await (await notebook.explorer.getMySQLAdminElement(constants.clientConnections)).click();
                dialog = await driver
                    .wait(Misc.untilConfirmationDialogExists(" after switching to Client Connections page"),
                        constants.wait5seconds);
                expect(await (await dialog!.findElement(locator.confirmDialog.message))
                    .getText())
                    .toMatch(new RegExp(toMatch));
                await dialog!.findElement(locator.confirmDialog.cancel).click();
                expect((await notebook.toolbar.getCurrentEditor())?.label).toBe(constants.dbNotebook);

                await (await notebook.explorer.getMySQLAdminElement(constants.performanceDashboard)).click();
                dialog = await driver
                    .wait(Misc.untilConfirmationDialogExists(" after switching to Performance Dashboard page"),
                        constants.wait5seconds);
                expect(await (await dialog!.findElement(locator.confirmDialog.message))
                    .getText())
                    .toMatch(new RegExp(toMatch));
                await dialog!.findElement(locator.confirmDialog.cancel).click();
                expect((await notebook.toolbar.getCurrentEditor())?.label).toBe(constants.dbNotebook);

                const connectionBrowser = await driver.wait(until.elementLocated(locator.dbConnectionOverview.tab),
                    constants.wait5seconds, "DB Connection Overview tab was not found");
                await connectionBrowser.click();

                dialog = await driver
                    .wait(Misc.untilConfirmationDialogExists(" after switching to DB Connections Overview page"),
                        constants.wait5seconds);
                expect(await (await dialog!.findElement(locator.confirmDialog.message))
                    .getText())
                    .toMatch(new RegExp(toMatch));
                await dialog!.findElement(locator.confirmDialog.cancel).click();
                await notebook.toolbar.selectEditor(new RegExp(script));

                dialog = await driver.wait(Misc.untilConfirmationDialogExists(" after switching to a script page"),
                    constants.wait5seconds);
                expect(await (await dialog!.findElement(locator.confirmDialog.message))
                    .getText())
                    .toMatch(new RegExp(toMatch));
                await dialog!.findElement(locator.confirmDialog.refuse).click();
            } catch (e) {
                testFailed = true;
                throw e;
            }

        });

    });

});

