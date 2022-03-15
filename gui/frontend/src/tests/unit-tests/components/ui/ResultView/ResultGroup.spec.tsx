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

import { render } from "@testing-library/preact";
import { shallow } from "enzyme";
import React from "react";
import { ResultGroup } from "../../../../../components/ResultView";
import { ITabviewProperties } from "../../../../../components/ui";

describe("Result group tests", (): void => {

    it("Result group elements", () => {
        const component = shallow<ITabviewProperties>(
            <ResultGroup
                id="resultGroup1"
                className="resultGroup"
                resultSet={{
                    head: {
                        requestId: "123",
                        sql: "select 1",
                    },
                    data: {
                        requestId: "123",
                        rows: [],
                        columns: [],
                        currentPage: 0,
                    },
                }}
            />,
        );

        expect(component).toBeTruthy();
        const props = component.props();
        expect(props.className).toEqual("resultGroup");
        expect(props.hideSingleTab).toEqual(true);
        expect(props.selectedId).toEqual("resultSet");
        expect(props.stretchTabs).toEqual(false);
        expect(props.tabPosition).toEqual("right");
        expect(props.onSelectTab).toBeDefined();
    });

    it("Result group (Snapshot) 1", () => {
        const component = render(
            <ResultGroup
                id="resultGroup1"
                className="resultGroup"
                resultSet={{
                    head: {
                        requestId: "123",
                        sql: "select 1",
                    },
                    data: {
                        requestId: "123",
                        rows: [],
                        columns: [],
                        currentPage: 0,
                    },
                }}
            />,
        );
        expect(component).toMatchSnapshot();
    });

});
