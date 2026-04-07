#!/usr/bin/env python3
"""
MEDUSA — AI Verification Engine
Fase 2: Lê o relatório da Fase 1 e verifica vulnerabilidades confirmadas
com guardrails legais rigorosos
"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime

from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent.parent / ".env")

# Importar o client de IA do analyze.py
sys.path.insert(0, str(Path(__file__).parent))
from analyze import call_ai, AI_PROVIDER


def load_bounty_scope(config_dir: Path) -> str:
    """Carrega o escopo do programa de bug bounty do targets.yaml."""
    import yaml
    targets_file = config_dir / "targets.yaml"
    if not targets_file.exists():
        return "Escopo não definido — use apenas o domínio principal"

    try:
        with open(targets_file) as f:
            data = yaml.safe_load(f)
        scope = data.get("scope", {})
        return json.dumps(scope, indent=2, ensure_ascii=False)
    except Exception:
        return targets_file.read_text()


def verify(target: str, output_dir: Path, config_dir: Path) -> dict:
    print(f"[+] Iniciando verificação de vulnerabilidades para: {target}")

    # Carregar relatório fase 1
    phase1_report = output_dir / "reports" / "phase1_analysis.json"
    if not phase1_report.exists():
        print("[-] Relatório da Fase 1 não encontrado. Execute analyze.py primeiro.")
        sys.exit(1)

    analysis = json.loads(phase1_report.read_text(encoding="utf-8"))
    bounty_scope = load_bounty_scope(config_dir)

    # Filtrar apenas findings que valem verificar
    vulns_to_verify = [
        v for v in analysis.get("vulnerabilities", [])
        if v.get("report_to_bounty", False) and not v.get("is_false_positive", True)
    ]

    print(f"[*] Vulnerabilidades para verificar: {len(vulns_to_verify)}")

    if not vulns_to_verify:
        print("[!] Nenhuma vulnerabilidade elegível para verificação")
        return {"target": target, "findings": [], "skipped_findings": []}

    # Carregar prompt
    prompt_file = Path(__file__).parent.parent / "prompts" / "exploitation_check.md"
    prompt_template = prompt_file.read_text(encoding="utf-8")

    prompt = prompt_template \
        .replace("{VULNERABILITY_REPORT}", json.dumps(vulns_to_verify, indent=2, ensure_ascii=False)) \
        .replace("{BOUNTY_SCOPE}", bounty_scope)

    print(f"[*] Enviando para IA ({AI_PROVIDER}) para análise legal...")
    response = call_ai(prompt)

    # Parsear resposta
    try:
        start = response.find("{")
        end = response.rfind("}") + 1
        verification_plan = json.loads(response[start:end]) if start >= 0 else {"raw": response}
    except json.JSONDecodeError:
        verification_plan = {"raw": response}

    verification_plan["target"] = target
    verification_plan["verification_date"] = datetime.now().isoformat()

    # Salvar plano de verificação
    plan_path = output_dir / "reports" / "phase2_verification_plan.json"
    plan_path.write_text(json.dumps(verification_plan, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"[+] Plano de verificação salvo em: {plan_path}")

    # Executar apenas verificações passivas automaticamente
    # Verificações ativas requerem aprovação manual
    findings = verification_plan.get("findings", [])
    passive_count = sum(1 for f in findings if f.get("verification_method") == "passive")
    active_count = sum(1 for f in findings if f.get("verification_method") == "active")
    skip_count = len(verification_plan.get("skipped_findings", []))

    print(f"[+] Plano: {passive_count} passivas, {active_count} ativas (requerem aprovação), {skip_count} ignoradas")

    return verification_plan


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 verify.py <target_domain>")
        sys.exit(1)

    target = sys.argv[1]
    base_dir = Path(__file__).parent.parent.parent
    output_dir = base_dir / "output"
    config_dir = base_dir / "config"

    result = verify(target, output_dir, config_dir)

    findings = result.get("findings", [])
    legal = sum(1 for f in findings if f.get("legal_to_test", False))
    skipped = len(result.get("skipped_findings", []))

    print(json.dumps({
        "phase": "ai_analysis",
        "step": "phase2_verification",
        "target": target,
        "total_findings": len(findings),
        "legal_to_test": legal,
        "skipped": skipped,
        "report_file": str(output_dir / "reports" / "phase2_verification_plan.json")
    }))
