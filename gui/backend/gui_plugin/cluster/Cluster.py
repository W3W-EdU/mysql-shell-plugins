# Copyright (c) 2020, 2024, Oracle and/or its affiliates.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2.0,
# as published by the Free Software Foundation.
#
# This program is designed to work with certain software (including
# but not limited to OpenSSL) that is licensed under separate terms, as
# designated in a particular file or component or in included license
# documentation.  The authors of MySQL hereby grant you an additional
# permission to link the program and your derivative works with the
# separately licensed software that they have either included with
# the program or referenced in the documentation.
#
# This program is distributed in the hope that it will be useful,  but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
# the GNU General Public License, version 2.0, for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA

from mysqlsh.plugin_manager import plugin_function  # pylint: disable=no-name-in-module


@plugin_function('gui.cluster.isGuiModuleBackend', web=True)
def is_gui_module_backend():
    """Indicates whether this module is a GUI backend module

    Returns:
        False
    """
    return False


@plugin_function('gui.cluster.getGuiModuleDisplayInfo', web=True)
def get_gui_module_display_info():
    """Returns display information about the module

    Returns:
        A dict with display information for the module
    """
    return {"name": "InnoDB Cluster Manager",
            "description": "An graphical manager for InnoDB Clusters",
            "icon_path": "/images/icons/modules/gui.cluster.svg"}
