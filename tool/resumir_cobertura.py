"""Resume LCOV sem dependencias externas e sem alterar os resultados."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORE_DIRS = {"modelos", "persistencia", "contas", "importacao", "exportacao", "backup"}


def main():
    files = []
    name, covered, total = "", 0, 0
    for line in (ROOT / "coverage" / "lcov.info").read_text(encoding="utf-8").splitlines():
        if line.startswith("SF:"):
            name, covered, total = line[3:].replace("\\", "/"), 0, 0
        elif line.startswith("DA:"):
            total += 1
            covered += int(line.split(",")[1]) > 0
        elif line == "end_of_record":
            files.append({"arquivo": name, "cobertas": covered, "total": total})

    def summarize(items):
        hit = sum(item["cobertas"] for item in items)
        count = sum(item["total"] for item in items)
        return {"cobertas": hit, "total": count, "percentual": round(100 * hit / count, 2) if count else 0}

    core = [item for item in files if len(parts := item["arquivo"].split("/")) > 2
            and parts[0] == "lib" and parts[1] in CORE_DIRS and not parts[-1].startswith("tela_")]
    print(json.dumps({"global": summarize(files), "nucleo": summarize(core),
                      "criterio_nucleo": "modelos, persistencia, contas, importacao, exportacao e backup; sem telas",
                      "arquivos": files}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
