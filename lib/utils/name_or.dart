// SPDX-FileCopyrightText: 2026-Present Odango contributors
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:odango/utils/chat/display_text.dart';
import 'package:odango/utils/visible_id.dart';

String nameOr(String name, String fallback) =>
    safeDisplayText(name).isEmpty ? visibleId(fallback) : name;
