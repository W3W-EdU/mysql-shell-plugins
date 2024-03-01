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

import { until, WebElement, error } from "selenium-webdriver";
import { explicitWait } from "./misc.js";
import * as locator from "../lib/locators.js";
import { driver } from "../lib/driver.js";

export class ShellSession {

    /**
     * Returns the result of a shell session query or instruction
     * @returns Promise resolving width the result
     *
     */
    public static getResult = async (): Promise<string> => {
        let text = "";
        const zoneHosts = await driver.findElements(locator.shellSession.result.exists);
        if (zoneHosts.length > 0) {
            const actions = await zoneHosts[zoneHosts.length - 1].findElements(locator.shellSession.result.action);
            if (actions.length > 0) {
                for (const action of actions) {
                    const spans = await action.findElements(locator.htmlTag.span);
                    for (const span of spans) {
                        text += `${await span.getText()}\r\n`;
                    }
                }
            } else {
                // Query results
                const resultStatus = await zoneHosts[zoneHosts.length - 1]
                    .findElements(locator.shellSession.result.info);
                if (resultStatus.length > 0) {
                    text = await resultStatus[0].getText();
                }
            }
        } else {
            throw new Error("Could not find any zone hosts");
        }

        return text;
    };

    /**
     * Returns the result of a shell session query or instruction that should generate a json result
     * @returns Promise resolving width the result
     *
     */
    public static getJsonResult = async (): Promise<string> => {
        const results = await driver.findElements(locator.shellSession.result.json);

        return results[results.length - 1].getAttribute("innerHTML");
    };

    /**
     * Verifies if the last output result is JSON
     * @returns Promise resolving with the result language
     */
    public static isJSON = async (): Promise<boolean> => {
        await driver.wait(until.elementLocated(locator.shellSession.result.exists), explicitWait);
        const zoneHosts = await driver.findElements(locator.shellSession.result.exists);
        const zoneHost = zoneHosts[zoneHosts.length - 1];

        const json = await zoneHost.findElements(locator.shellSession.result.json);

        return json.length > 0;
    };

    /**
     * Returns the shell session tab
     * @param sessionNbr the session number
     * @returns Promise resolving with the the Session tab
     */
    public static getTab = async (sessionNbr: string): Promise<WebElement> => {
        const tabArea = await driver.findElement(locator.shellSession.result.tabs);
        await driver.wait(
            async () => {
                return (
                    (
                        await tabArea.findElements(
                            locator.shellSession.result.searchBySessionId(sessionNbr),
                        )
                    ).length > 0
                );
            },
            10000,
            "Session was not opened",
        );

        return tabArea.findElement(
            locator.shellSession.result.searchBySessionId(sessionNbr),
        );
    };

    /**
     * Closes a shell session
     * @param sessionNbr the session number
     * @returns Promise resolving when the session is closed
     */
    public static closeSession = async (sessionNbr: string): Promise<void> => {
        const tab = await ShellSession.getTab(sessionNbr);
        await tab.findElement(locator.shellSession.close).click();
    };

    /**
     * Returns the Shell tech/language after switching to javascript/python/mysql
     * @returns Promise resolving with the the session shell language
     */
    public static getTech = async (): Promise<string> => {
        const editorsPrompt = await driver.findElements(locator.shellSession.language);
        const lastEditorClasses = await editorsPrompt[editorsPrompt.length - 1].getAttribute("class");

        return lastEditorClasses.split(" ")[2];
    };

    /**
     * Verifies if a value is present on a query result data set
     * @param value value to search for
     * @returns A promise resolving with true if exists, false otherwise
     */
    public static isValueOnDataSet = async (value: string): Promise<boolean | undefined> => {
        const checkValue = async (): Promise<boolean | undefined> => {
            const zoneHosts = await driver.findElements(locator.shellSession.result.exists);
            const cells = await zoneHosts[zoneHosts.length - 1].findElements(locator.shellSession.result.dataSet.cells);
            for (const cell of cells) {
                const text = await cell.getText();
                if (text === value) {
                    return true;
                }
            }
        };

        return driver.wait(async () => {
            try {
                return await checkValue();
            } catch (e) {
                if (!(e instanceof error.StaleElementReferenceError)) {
                    throw e;
                }
            }
        }, explicitWait, "");
    };

    /**
     * Returns the text within the server tab on a shell session
     * @returns A promise resolving with the text on the tab
     */
    public static getServerTabStatus = async (): Promise<string> => {
        const server = await driver.findElement(locator.shellSession.server);

        return server.getAttribute("data-tooltip");
    };

    /**
     * Returns the text within the schema tab on a shell session
     * @returns A promise resolving with the text on the tab
     */
    public static getSchemaTabStatus = async (): Promise<string> => {
        const schema = await driver.findElement(locator.shellSession.schema);

        return schema.getAttribute("innerHTML");
    };

    /**
     * Verifies if a text is present on a json result, returned by a query
     * @param value value to search for
     * @returns A promise resolving with true if exists, false otherwise
     */
    public static isValueOnJsonResult = async (value: string): Promise<boolean> => {
        const zoneHosts = await driver.findElements(locator.shellSession.result.exists);
        const zoneHost = zoneHosts[zoneHosts.length - 1];
        const spans = await zoneHost.findElements(locator.htmlTag.mix(
            locator.htmlTag.label.value,
            locator.htmlTag.span.value,
            locator.htmlTag.span.value,
        ));

        for (const span of spans) {
            const spanText = await span.getText();
            if (spanText.indexOf(value) !== -1) {
                return true;
            }
        }

        return false;
    };

    /**
     * Waits for the text or regexp to include/match the result of a shell session query or instruction
     * @param text text of regexp to verify
     * @param isJson true if expected result should be json
     * @returns Promise resolving when the text or the regexp includes/matches the query result
     *
     */
    public static waitForResult = async (text: string | RegExp, isJson = false): Promise<void> => {
        let result: string;
        await driver.wait(async () => {
            if (typeof text === "object") {
                return (await ShellSession.getResult()).match(text);
            } else {
                if (isJson) {
                    result = await ShellSession.getJsonResult();
                } else {
                    result = await ShellSession.getResult();
                }

                return result.includes(text);
            }
        }, explicitWait, `'${String(text)}' was not found on result`);
    };

    /**
     * Waits for the connection tab (server/schema) includes the given text
     * @param tab server or schema
     * @param text to verify
     * @returns Promise resolving when the text of the tab includes the given text
     *
     */
    public static waitForConnectionTabValue = async (tab: string, text: string): Promise<void> => {
        if (tab === "server") {
            await driver.wait(async () => {
                return (await ShellSession.getServerTabStatus()).includes(text);
            }, explicitWait, `'${text}' was not found on the server tab`);
        } else {
            await driver.wait(async () => {
                return (await ShellSession.getSchemaTabStatus()).includes(text);
            }, explicitWait, `'${text}' was not found on the schema tab`);
        }
    };

    /**
     * Clicks on the schema tab and selects a new schema
     * @param schema schema to choose
     * @returns Promise resolving when the new schema is selected
     *
     */
    public static changeSchemaOnTab = async (schema: string): Promise<void> => {
        await driver.findElement(locator.shellSession.schema).click();
        const menuItems = await driver.wait(until.elementsLocated(locator.shellSession.tabContextMenu),
            explicitWait, "Menu items were not found");

        for (const item of menuItems) {
            const label = await item.getText();
            if (label.includes(schema)) {
                await item.click();

                return;
            }
        }

        await ShellSession.waitForResult("Default schema `" + schema + "` accessible through db.");
    };

}
