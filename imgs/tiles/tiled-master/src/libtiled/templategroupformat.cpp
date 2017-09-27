/*
 * templategroupformat.cpp
 * Copyright 2017, Thorbjørn Lindeijer <thorbjorn@lindeijer.nl>
 * Copyright 2017, Mohamed Thabet <thabetx@gmail.com>
 *
 * This file is part of Tiled.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include "templategroupformat.h"

#include "mapreader.h"

namespace Tiled {

TemplateGroup *readTemplateGroup(const QString &fileName, QString *error)
{
    if (TemplateGroupFormat *format = findSupportingGroupFormat(fileName)) {
        TemplateGroup *templateGroup = format->read(fileName);

        if (error) {
            if (!templateGroup)
                *error = format->errorString();
            else
                *error = QString();
        }

        if (templateGroup)
            templateGroup->setFormat(format);

        return templateGroup;
    }

    MapReader reader;
    TemplateGroup *templateGroup = reader.readTemplateGroup(fileName);

    if (error) {
        if (!templateGroup)
            *error = reader.errorString();
        else
            *error = QString();
    }

    return templateGroup;
}

TemplateGroupFormat *findSupportingGroupFormat(const QString &fileName)
{
    for (TemplateGroupFormat *format : PluginManager::objects<TemplateGroupFormat>())
        if (format->supportsFile(fileName))
            return format;
    return nullptr;
}

} // namespace Tiled
