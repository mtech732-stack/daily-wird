#!/usr/bin/env python3
"""فحص 4.4 في الكود: كل خاصية مخزّنة في كيانات SwiftData اختيارية أو لها قيمة افتراضية،
ولا `.unique` ولا `#Unique`، ولا `let` مخزّنة، وكل علاقة اختيارية.
يجمع التصريح الممتدّ على أكثر من سطر قبل فحصه (م15).
الاستعمال: check-cloudkit-model.py App/Model/*.swift
"""
import re, sys

DECL = re.compile(r"\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:private|fileprivate|internal|public)(?:\(set\))?\s+)*(var|let)\s+(\w+)\s*(?::\s*([^={]+?))?\s*(=.*)?$")


def logical_lines(lines):
    """يجمع السطر الذي لم يكتمل تصريحه (ينتهي بـ : أو = أو , أو اسم var/let وحده) مع ما بعده."""
    i = 0
    while i < len(lines):
        start, code = i + 1, lines[i].split("//")[0].rstrip()
        while i + 1 < len(lines) and (
            code.endswith((":", "=", ",", "->"))
            or re.search(r"\b(var|let)\s+\w+\s*$", code)
            or re.match(r"\s*@\w+(\([^)]*\))?\s*$", code)
        ):
            i += 1
            code = code + " " + lines[i].split("//")[0].strip()
        yield start, code
        i += 1


errors = []
for path in sys.argv[1:]:
    lines = open(path, encoding="utf-8").read().splitlines()
    in_model = False
    depth = 0
    for n, code in logical_lines(lines):
        if ".unique" in code or "#Unique" in code:
            errors.append(f"{path}:{n}: قيد تفرّد")
        if code.strip() == "@Model" or code.strip().startswith("@Model "):
            in_model, depth = True, None
            if "{" not in code:
                continue
        if in_model:
            if depth is None:
                if "{" in code:
                    depth = code.count("{") - code.count("}")
                continue
            # الخصائص المخزّنة في مستوى الكيان الأول وحده (لا داخل الدوالّ والخصائص المحسوبة).
            if depth == 1 and "{" not in code:
                m = DECL.match(code)
                if m and "static" not in code and "@Transient" not in code:
                    kind, name, typ, default = m.group(1), m.group(2), (m.group(3) or "").strip(), m.group(4)
                    if kind == "let":
                        errors.append(f"{path}:{n}: الخاصية {name} ثابتة (let)؛ تكون var اختيارية أو بقيمة افتراضية")
                    elif not typ.endswith("?") and not default:
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
