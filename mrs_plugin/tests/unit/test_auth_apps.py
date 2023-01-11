# Copyright (c) 2021, 2023, Oracle and/or its affiliates.
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
from ... auth_apps import *
from ... import lib

InitialAuthAppIds = []

@pytest.mark.usefixtures("init_mrs")
def test_add_auth_vendors(init_mrs, table_contents):
    auth_vendor_table = table_contents("auth_vendor")

    assert auth_vendor_table.count == 5
    assert auth_vendor_table.items == [{
        'comments': 'Built-in user management of MRS',
        'enabled': 1,
        'id': lib.core.id_to_binary("0x30000000000000000000000000000000", ""),
        'name': 'MRS',
        'validation_url': 'NULL'
    },
    {
        'comments': 'Provides basic authentication via MySQL Server accounts',
        'enabled': 1,
        'id': lib.core.id_to_binary("0x31000000000000000000000000000000", ""),
        'name': 'MySQL Internal',
        'validation_url': 'NULL'
    },
    {
        'comments': 'Uses the Facebook Login OAuth2 service',
        'enabled': 1,
        'id': lib.core.id_to_binary("0x32000000000000000000000000000000", ""),
        'name': 'Facebook',
        'validation_url': 'NULL'
    },
    {
        'comments': 'Uses the Twitter OAuth2 service',
        'enabled': 1,
        'id': lib.core.id_to_binary("0x33000000000000000000000000000000", ""),
        'name': 'Twitter',
        'validation_url': 'NULL'
    },
    {
        'comments': 'Uses the Google OAuth2 service',
        'enabled': 1,
        'id': lib.core.id_to_binary("0x34000000000000000000000000000000", ""),
        'name': 'Google',
        'validation_url': 'NULL'
    }]


@pytest.mark.usefixtures("init_mrs")
def test_add_auth_apps(init_mrs, table_contents):
    auth_apps_table = table_contents("auth_app")

    args = {
        "auth_vendor_id": "0x30000000000000000000000000000000",
        "description": "Authentication via MySQL accounts",
        "url": "/test_auth",
        "access_token": "test_token",
        "limit_to_registered_users": False,
        "registered_users": "root",
        "app_id": "some app id",
        "session": init_mrs["session"]
    }

    result = add_auth_app(app_name="Test Auth App", service_id=init_mrs["service_id"], **args)
    assert result is not None
    InitialAuthAppIds.append(result["auth_app_id"])
    assert auth_apps_table.count == auth_apps_table.snapshot.count + 1
    assert auth_apps_table.get("id", result["auth_app_id"]) == {
        'access_token': args["access_token"],
        'app_id': args["app_id"],
        'auth_vendor_id': lib.core.id_to_binary(args['auth_vendor_id'], ""),
        'default_role_id': None,
        'description': args["description"],
        'enabled': 1,
        'id': result["auth_app_id"],
        'limit_to_registered_users': int(args["limit_to_registered_users"]),
        'name': 'Test Auth App',
        'service_id': init_mrs["service_id"],
        'url': args["url"],
        'url_direct_auth': None,
        'use_built_in_authorization': 1
    }

    args = {
        "auth_vendor_id": "0x30000000000000000000000000000000",
        "description": "Authentication via MySQL accounts 2",
        "url": "/test_auth2",
        "access_token": "test_token",
        "limit_to_registered_users": False,
        "registered_users": "root",
        "app_id": "some app id",
        "session": init_mrs["session"]
    }

    result = add_auth_app(app_name="Test Auth App 2", service_id=init_mrs["service_id"], **args)
    assert result is not None
    InitialAuthAppIds.append(result["auth_app_id"])
    assert auth_apps_table.count == auth_apps_table.snapshot.count + 2
    assert auth_apps_table.get("id", result["auth_app_id"]) == {
        'access_token': args["access_token"],
        'app_id': args["app_id"],
        'auth_vendor_id': lib.core.id_to_binary(args['auth_vendor_id'], ""),
        'default_role_id': None,
        'description': args["description"],
        'enabled': 1,
        'id': result["auth_app_id"],
        'limit_to_registered_users': int(args["limit_to_registered_users"]),
        'name': 'Test Auth App 2',
        'service_id': init_mrs["service_id"],
        'url': args["url"],
        'url_direct_auth': None,
        'use_built_in_authorization': 1
    }

@pytest.mark.usefixtures("init_mrs")
def test_get_auth_apps(init_mrs):
    args = {
        "include_enable_state": False,
        "session": init_mrs["session"],
    }
    apps = get_auth_apps(**args)
    assert apps == []

    args = {
        "include_enable_state": True,
        "session": init_mrs["session"],
    }
    apps = get_auth_apps(**args)

    assert apps is not None
    assert len(apps) == 2

    assert apps[0]["name"] == "Test Auth App"
    assert apps[0]["id"] == InitialAuthAppIds[0]
    assert apps[1]["name"] == "Test Auth App 2"
    assert apps[1]["id"] == InitialAuthAppIds[1]


@pytest.mark.usefixtures("init_mrs")
def test_update_auth_apps(init_mrs, table_contents):
    auth_apps_table = table_contents("auth_app")
    value = {
        "name": "Test Auth App New",
        "description": "This is a new description",
        "url": "/test_app_new",
        "url_direct_auth": "new url direct auth",
        "access_token": "new access token",
        "app_id": "new app id",
        "enabled": False,
        "use_built_in_authorization": False,
        "limit_to_registered_users": False,
        "default_role_id": None
    }
    args = {
        "app_id": InitialAuthAppIds[0],
        "session": init_mrs["session"],
        "value": value
    }
    update_auth_app(**args)

    assert auth_apps_table.count == auth_apps_table.snapshot.count

    assert auth_apps_table.get("id", args["app_id"]) == {
        'access_token': value["access_token"],
        'app_id': value["app_id"],
        'auth_vendor_id': lib.core.id_to_binary("0x30000000000000000000000000000000", ""),
        'default_role_id': value["default_role_id"],
        'description': value["description"],
        'enabled': int(value["enabled"]),
        'id': args["app_id"],
        'limit_to_registered_users': int(value["limit_to_registered_users"]),
        'name': value["name"],
        'service_id': init_mrs["service_id"],
        'url': value["url"],
        'url_direct_auth': value["url_direct_auth"],
        'use_built_in_authorization': int(value["use_built_in_authorization"])
    }


@pytest.mark.usefixtures("init_mrs")
def test_delete_auth_apps(init_mrs, table_contents):
    auth_apps_table = table_contents("auth_app")

    assert auth_apps_table.count == 2

    delete_auth_app(session=init_mrs["session"], app_id=InitialAuthAppIds[0])

    assert auth_apps_table.count == 1

    delete_auth_app(session=init_mrs["session"], app_id=InitialAuthAppIds[1])

    assert auth_apps_table.count == 0
