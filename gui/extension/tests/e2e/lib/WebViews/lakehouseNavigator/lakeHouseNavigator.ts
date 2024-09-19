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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
 * the GNU General Public License, version 2.0, for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 */

import { Condition } from "vscode-extension-tester";
import { driver, Misc } from "../../Misc";
import * as constants from "../../constants";
import * as locator from "../../locators";
import { Overview } from "./overview";
import { UploadToObjectStorage } from "./uploadToObjectStorage";
import { LoadIntoLakehouse } from "./loadIntoLakeHouse";
import { LakehouseTables } from "./lakehouseTables";
import { Toolbar } from "../Toolbar";
import { PasswordDialog } from "../Dialogs/PasswordDialog";
import * as interfaces from "../../interfaces";

/**
 * This class aggregates the functions that perform password dialog related operations
 */
export class LakeHouseNavigator {

    public toolbar = new Toolbar();

    public overview = new Overview();

    public uploadToObjectStorage = new UploadToObjectStorage();

    public loadIntoLakehouse = new LoadIntoLakehouse();

    public lakehouseTables = new LakehouseTables();

    /**
     * Verifies if the Lakehouse Navigator page is opened and fully loaded
     * @param connection The DB Connection
     * @returns A condition resolving to true if the page is loaded, false otherwise
     */
    public untilIsOpened = (connection: interfaces.IDBConnection): Condition<boolean> => {
        return new Condition(`for Lakehouse Navigator to be opened`, async () => {
            await Misc.switchBackToTopFrame();
            await Misc.switchToFrame();

            const isOpened = async (): Promise<boolean> => {
                return (await driver.findElements(locator.lakeHouseNavigator.exists)).length > 0;
            };

            if (await PasswordDialog.exists()) {
                await PasswordDialog.setCredentials(connection);

                return driver.wait(async () => {
                    return isOpened();
                }, constants.wait10seconds)
                    .catch(async () => {
                        const existsErrorDialog = (await driver.findElements(locator.errorDialog.exists)).length > 0;
                        if (existsErrorDialog) {
                            const errorDialog = await driver.findElement(locator.errorDialog.exists);
                            const errorMsg = await errorDialog.findElement(locator.errorDialog.message);
                            throw new Error(await errorMsg.getText());
                        } else {
                            throw new Error("Unknown error");
                        }
                    });
            } else {
                return isOpened();
            }
        });
    };

    /**
     * Selects a tab
     * @param tabName The tab name
     * @returns A promise resolving when the tab is selected
     */
    public selectTab = async (tabName: string): Promise<void> => {
        await Misc.switchBackToTopFrame();
        await Misc.switchToFrame();

        switch (tabName) {
            case constants.overviewTab: {
                await driver.findElement(locator.lakeHouseNavigator.overview.tab).click();
                this.overview = new Overview();
                break;
            }
            case constants.uploadToObjectStorageTab: {
                await driver.findElement(locator.lakeHouseNavigator.uploadToObjectStorage.tab).click();
                this.uploadToObjectStorage = new UploadToObjectStorage();
                break;
            }
            case constants.loadIntoLakeHouseTab: {
                await driver.findElement(locator.lakeHouseNavigator.loadIntoLakeHouse.tab).click();
                this.loadIntoLakehouse = new LoadIntoLakehouse();
                break;
            }
            case constants.lakeHouseTablesTab: {
                await driver.findElement(locator.lakeHouseNavigator.lakeHouseTables.tab).click();
                this.lakehouseTables = new LakehouseTables();
                break;
            }
            default: {
                throw new Error(`Unknown tab '${tabName}'`);
            }
        }
    };

}

