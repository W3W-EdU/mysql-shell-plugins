# Copyright (c) 2021, 2022, Oracle and/or its affiliates.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2.0,
# as published by the Free Software Foundation.
#
# This program is also distributed with certain software (including
# but not limited to OpenSSL) that is licensed under separate terms, as
# designated in a particular file or component or in included license
# documentation.  The authors of MySQL hereby grant you an additional
# permission to link the program and your derivative works with the
# separately licensed software that they have included with MySQL.
# This program is distributed in the hope that it will be useful,  but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License, version 2.0, for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

import pytest
import tempfile
import json
import mysqlsh

from lib.core import MrsDbSession
from ... content_sets import *

@pytest.mark.usefixtures("init_mrs")
def test_add_content_set(init_mrs, table_contents):
    table_content_set = table_contents("content_set")
    assert table_content_set.snapshot.count == 1

    with tempfile.TemporaryDirectory() as tmp:
        content_set = {
            "request_path": "test_content_set2",
            "requires_auth": False,
            "comments": "Content Set",
            "session": init_mrs
        }

        with pytest.raises(Exception) as exc_info:
            result = add_content_set(content_dir=None, service_id=1, **content_set)
        assert str(exc_info.value) == "The request_path has to start with '/'."
        assert table_content_set.same_as_snapshot

        content_set["request_path"] = "/test_content_set2"
        result = add_content_set(content_dir=tmp, service_id=1, **content_set)
        assert result is not None
        assert result == {
            'content_set_id': 2,
            'number_of_files_uploaded': 0
        }
        table_content_set.count == table_content_set.snapshot.count + 1

        result = delete_content_set(content_set_id=result["content_set_id"], session=content_set["session"])
        assert result is not None
        assert result == "The content set has been deleted."
        assert table_content_set.same_as_snapshot


    assert table_content_set.same_as_snapshot

@pytest.mark.usefixtures("init_mrs")
def test_get_content_sets(init_mrs, table_contents):
    table_content_set = table_contents("content_set")
    assert table_content_set.snapshot.count == 1

    args = {
            "include_enable_state": None,
            "session": init_mrs,
    }

    sets = get_content_sets(1, **args)
    assert sets is not None
    assert sets ==  [{
        'id': 1,
        'options': None,
        'request_path': '/test_content_set',
        'requires_auth': 0,
        'enabled': 1,
        'comments': 'Content Set',
        'host_ctx': 'localhost/test'
    }]


@pytest.mark.usefixtures("init_mrs")
def test_get_content_set(init_mrs):
    with MrsDbSession(session=init_mrs) as session:
        content_set_1 = {
            'id': 1,
            'request_path': '/test_content_set',
            'requires_auth': 0,
            'enabled': 1,
            'comments': 'Content Set',
            'host_ctx': 'localhost/test',
            "options": None,
        }
        args = {
                "content_set_id": 1,
                "service_id": 1,
                "session": session,
                "auto_select_single": True
        }

        # test for non existing content set
        args["content_set_id"] = 10
        with pytest.raises(Exception) as exc_info:
            get_content_set(request_path="test_content_set", **args)
        assert str(exc_info.value) == "The request_path has to start with '/'."

        args["content_set_id"] = 1
        sets = get_content_set(**args)
        assert sets == content_set_1

        get_content_set(request_path="/test_content_set", **args)
        assert sets == content_set_1

        del args["content_set_id"]
        sets = get_content_set(request_path="/test_content_set", **args)
        assert sets == content_set_1

@pytest.mark.usefixtures("init_mrs")
def test_enable_disable(init_mrs, table_contents):
    content_set_table = table_contents("content_set")
    args = {
            "content_set_id": 999,
            "service_id": 1,
            "session": init_mrs
    }

    with pytest.raises(Exception) as exc_info:
        result = disable_content_set(**args)
    assert str(exc_info.value) == "The specified content_set was not found."



    with pytest.raises(Exception) as exc_info:
        result = disable_content_set(**args)
    assert str(exc_info.value) == "The specified content_set was not found."

    assert content_set_table.snapshot.get("id", 1)["enabled"] == True
    args["content_set_id"] = 1
    result = disable_content_set(**args)
    assert result is not None
    assert result == "The content set has been disabled."
    assert content_set_table.get("id", 1)["enabled"] == False

    result = enable_content_set(**args)
    assert result is not None
    assert result == "The content set has been enabled."
    assert content_set_table.get("id", 1)["enabled"] == True
    assert content_set_table.same_as_snapshot

