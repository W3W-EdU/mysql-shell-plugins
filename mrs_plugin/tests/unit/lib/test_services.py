# Copyright (c) 2022, Oracle and/or its affiliates.
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
from lib.core import MrsDbSession
from mrs_plugin import lib
from ..helpers import ServiceCT


@pytest.mark.usefixtures("init_mrs")
def test_get_service(init_mrs, table_contents):
    with MrsDbSession(session=init_mrs) as session:
        service_table = table_contents("service")
        service1 = lib.services.get_service(session=session, url_context_root="/test", url_host_name="localhost")

        assert service1 is not None
        assert service1 == {
            'id': 1,
            'enabled': 1,
            'url_protocol': ['HTTP'],
            'url_host_name': 'localhost',
            'url_context_root': '/test',
            'url_host_id': 1,
            'is_default': 0,
            'comments': 'Test service',
            'host_ctx': 'localhost/test',
            'auth_completed_page_content': None,
            'auth_completed_url': None,
            'auth_completed_url_validation': None,
            'auth_path': '/authentication',
            'options': None
        }

        with ServiceCT("/service2", "localhost") as service_id:
            assert service_table.count == service_table.snapshot.count + 1

            service2 = lib.services.get_service(session=session, url_context_root="/service2", url_host_name="localhost")

            assert service2 is not None
            assert service2 == {
                'id': service_id,
                'enabled': 1,
                'url_protocol': ['HTTP'],
                'url_host_name': 'localhost',
                'url_context_root': '/service2',
                'url_host_id': 1,
                'is_default': 0,
                'comments': "",
                'host_ctx': 'localhost/service2',
                'auth_completed_page_content': None,
                'auth_completed_url': None,
                'auth_completed_url_validation': None,
                'auth_path': '/authentication',
                'options': None
            }

            assert service_table.get("id", service_id) == {
                'comments': '',
                'enabled': 1,
                'id': service_id,
                'is_default': 0,
                'url_context_root': '/service2',
                'url_host_id': 1,
                'url_protocol': ['HTTP'],
                'auth_completed_page_content': None,
                'auth_completed_url': None,
                'auth_completed_url_validation': None,
                'auth_path': '/authentication',
                'options': None
            }

            with pytest.raises(Exception) as exc_info:
                lib.services.get_service(session=session, url_context_root="service2", url_host_name="localhost")
            assert str(exc_info.value) == "The url_context_root has to start with '/'."


            result = lib.services.get_service(session=session, url_context_root="/service2", url_host_name="localhost", get_default=True)
            assert result is None



@pytest.mark.usefixtures("init_mrs")
def test_change_service(init_mrs, table_contents):
    service_table = table_contents("service")
    auth_app_table = table_contents("auth_app")

    auth_apps = [{
        "auth_vendor_id": 1,
        "auth_vendor_name": "Service 1 app 1",
        "url_direct_auth": "/app1",
        "app_id": "my app id 1",
        "use_built_in_authorization": 1,
        "limit_to_registered_users": 0,
        "access_token": "TestToken1",
    }, {
        "auth_vendor_id": 1,
        "auth_vendor_name": "Service 1 app 2",
        "url_direct_auth": "/app2",
        "app_id": "my app id 2",
        "use_built_in_authorization": 1,
        "limit_to_registered_users": 0,
        "access_token": "TestToken2",
    }]

    with MrsDbSession(session=init_mrs) as session:
        with pytest.raises(Exception) as exc_info:
                lib.services.update_service(session=session, service_ids=[1000], value={"enabled": True})
        assert str(exc_info.value) == "The specified service with id 1000 was not found."

        with ServiceCT("/service2", "localhost", auth_apps=auth_apps) as service_id:
            auth_apps_in_db = auth_app_table.filter(f"service_id={service_id}")
            assert len(auth_apps_in_db) == 2

            value = {
                "auth_apps": [{
                    "id": auth_apps_in_db[0]["id"],
                    "auth_vendor_id": 1,
                    "auth_vendor_name": "Service 1 app 1 Updated",
                    "service_id": service_id,
                    "url_direct_auth": "/app2",
                    "app_id": "my app id 1 update",
                    "use_built_in_authorization": 1,
                    "limit_to_registered_users": 0,
                    "access_token": "TestToken2Updated",
                    "description": "This is a description 1"
                }, {
                    "id": -1,
                    "auth_vendor_id": 1,
                    "auth_vendor_name": "Service 1 app 3",
                    "service_id": service_id,
                    "url_direct_auth": "/app3",
                    "app_id": "my app id 3",
                    "use_built_in_authorization": 1,
                    "limit_to_registered_users": 0,
                    "access_token": "TestToken3",
                    "description": "This is a description 3"
                }],
                "comments": "This is the updated comment."
            }
            lib.services.update_service(session=session, service_ids=[service_id], value=value)

            auth_apps_in_db = auth_app_table.filter(f"service_id={service_id}")
            assert auth_apps_in_db == [{
                    "id": auth_apps_in_db[0]["id"],
                    "auth_vendor_id": 1,
                    "service_id": service_id,
                    "url_direct_auth": "/app2",
                    "app_id": "my app id 1 update",
                    "use_built_in_authorization": 1,
                    "limit_to_registered_users": 0,
                    "access_token": "TestToken2Updated",
                    "default_auth_role_id": None,
                    "description": "This is a description 1",
                    "enabled": None,
                    "url": None,
                    "name": None,
                }, {
                    "id": auth_apps_in_db[1]["id"],
                    "auth_vendor_id": 1,
                    "service_id": service_id,
                    "url_direct_auth": "/app3",
                    "app_id": "my app id 3",
                    "use_built_in_authorization": 1,
                    "limit_to_registered_users": 0,
                    "access_token": "TestToken3",
                    "default_auth_role_id": None,
                    "description": "This is a description 3",
                    "enabled": None,
                    "url": None,
                    "name": None,
                }]

    assert service_table.same_as_snapshot
    assert auth_app_table.same_as_snapshot
