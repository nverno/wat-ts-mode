#!/usr/bin/env python3

# https://webassembly.github.io/spec/core/appendix/index-instructions.html
# https://webassembly.github.io/spec/core/appendix/index-types.html

import requests

CORE_URL = "https://webassembly.github.io/spec/core/appendix/index-instructions.html"
WABT_KEYWORDS_URL = (
    "https://raw.githubusercontent.com/WebAssembly/wabt/main/src/lexer-keywords.txt"
)


def get_keywords_wabt(url):
    response = requests.get(url)
    response.raise_for_status()
    content = response.text.strip().split("\n")
    idx = content.index(next(line for line in content if "%%" in line))
    res = {"keywords": [], "types": [], "ops": []}
    for line in sorted(content[idx + 1:]):
        parts = line.lower().split(", ")
        if len(parts) == 2 and parts[1].startswith("type::"):
            res["types"].append(parts[0])
        elif len(parts) == 3 and parts[2].startswith("opcode::"):
            res["ops"].append(parts[0])
        else:
            res["keywords"].append(parts[0])
    return res


def fill_lines(lst, max_len=85):
    res, cur = [], ""
    for e in lst:
        if len(cur) + len(e) + 3 > max_len:
            res.append(cur)
            cur = ""
        cur += f" '{e}'"
    res.append(cur)
    return res


if __name__ == "__main__":
    import sys

    kws = get_keywords_wabt(WABT_KEYWORDS_URL)
    print(f"{sum(len(x) for x in kws.values())} total", file=sys.stderr)
    # assert(sum(len(x) for x in kws.values()) == 590)

    if len(sys.argv) > 1:
        print("\n".join(fill_lines(kws[sys.argv[1]])))
    else:
        for k, v in kws.items():
            print(k, "\n", "\n".join(fill_lines(v)))
