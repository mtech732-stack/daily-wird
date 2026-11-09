#!/usr/bin/env python3
"""فحص 4.4 في الكود: كل خاصية مخزّنة في كيانات SwiftData اختيارية أو لها قيمة افتراضية،
ولا `.unique`، وكل علاقة اختيارية.
الاستعمال: check-cloudkit-model.py App/Model/*.swift
"""
import re, sys

errors = []
for path in sys.argv[1:]:
    lines = open(path, encoding="utf-8").read().splitlines()
    in_model = False
    depth = 0
    for n, line in enumerate(lines, 1):
        code = line.split("//")[0]
        if ".unique" in code:
            errors.append(f"{path}:{n}: قيد تفرّد")
        if code.strip() == "@Model":
            in_model, depth = True, None
            continue
        if in_model:
            if depth is None:
                if "{" in code:
                    depth = code.count("{") - code.count("}")
                continue
            # الخصائص المخزّنة في مستوى الكيان الأول وحده (لا داخل الدوالّ والخصائص المحسوبة).
            if depth == 1:
                m = re.match(r"\s*(?:@\w+(?:\([^)]*\))?\s+)*var\s+(\w+)\s*:\s*([^={]+?)\s*(=.*)?$", code)
                if m and "{" not in code:
                    name, typ, default = m.group(1), m.group(2).strip(), m.group(3)
                    if not typ.endswith("?") and not default:
                        errors.append(f"{path}:{n}: الخاصية {name} ليست اختيارية ولا قيمة افتراضية لها")
                    if "@Relationship" in code and not typ.endswith("?") and not typ.startswith("["):
                        errors.append(f"{path}:{n}: العلاقة {name} ليست اختيارية")
            depth += code.count("{") - code.count("}")
            if depth <= 0:
                in_model = False

if errors:
    print("\n".join(errors))
    sys.exit(1)
print("4.4: كل الخصائص اختيارية أو لها قيم افتراضية، ولا قيود تفرّد.")
