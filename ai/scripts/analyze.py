#!/usr/bin/env python3
"""
MEDUSA — AI Analysis Engine
Fase 1: Lê todos os resultados de scan e gera relatório de vulnerabilidades
"""

import json
import os
import sys
from pathlib import Path
from datetime import datetime

from dotenv import load_dotenv

load_dotenv(Path(__file__).parent.parent.parent / ".env")

# ============================================================
# CONFIGURAÇÃO DE PROVIDER
# ============================================================

AI_PROVIDER = os.getenv("AI_PROVIDER", "ollama")  # ollama | anthropic | openai


def get_ai_client():
    if AI_PROVIDER == "anthropic":
        import anthropic
        return anthropic.Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
    elif AI_PROVIDER == "openai":
        import openai
        return openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
    else:
        return None  # Ollama usa requests direto


def call_ai(prompt: str, system: str = "") -> str:
    """Chama a IA configurada e retorna a resposta."""

    if AI_PROVIDER == "anthropic":
        client = get_ai_client()
        message = client.messages.create(
            model="claude-opus-4-6",
            max_tokens=8192,
            system=system or "Você é um especialista em segurança ofensiva e bug bounty.",
            messages=[{"role": "user", "content": prompt}]
        )
        return message.content[0].text

    elif AI_PROVIDER == "openai":
        client = get_ai_client()
        response = client.chat.completions.create(
            model="gpt-4o",
            max_tokens=8192,
            messages=[
                {"role": "system", "content": system or "Você é um especialista em segurança."},
                {"role": "user", "content": prompt}
            ]
        )
        return response.choices[0].message.content

    else:  # Ollama local
        import requests
        model = os.getenv("OLLAMA_MODEL", "llama3")
        host = os.getenv("OLLAMA_HOST", "http://localhost:11434")
        response = requests.post(
            f"{host}/api/generate",
            json={
                "model": model,
                "prompt": f"{system}\n\n{prompt}" if system else prompt,
                "stream": False
            },
            timeout=300
        )
        response.raise_for_status()
        return response.json()["response"]


# ============================================================
# COLETA DE RESULTADOS
# ============================================================

def load_scan_results(output_dir: Path) -> dict:
    """Carrega todos os resultados de scan disponíveis."""
    results = {}

    # Recon
    recon_dir = output_dir / "recon"
    if (recon_dir / "subdomains_resolved.txt").exists():
        results["subdomains"] = (recon_dir / "subdomains_resolved.txt").read_text()
    if (recon_dir / "whois_summary.txt").exists():
        results["whois"] = (recon_dir / "whois_summary.txt").read_text()
    if (recon_dir / "email_records.txt").exists():
        results["email_records"] = (recon_dir / "email_records.txt").read_text()

    # Active
    active_dir = output_dir / "active"
    if (active_dir / "http_alive.txt").exists():
        results["http_alive"] = (active_dir / "http_alive.txt").read_text()
    if (active_dir / "ports_detail.txt").exists():
        results["ports"] = (active_dir / "ports_detail.txt").read_text()

    # Vuln
    vuln_dir = output_dir / "vuln"
    if (vuln_dir / "nuclei_results.json").exists():
        try:
            nuclei_lines = (vuln_dir / "nuclei_results.json").read_text().strip().split("\n")
            results["nuclei"] = [json.loads(l) for l in nuclei_lines if l.strip()]
        except Exception:
            results["nuclei"] = (vuln_dir / "nuclei_results.json").read_text()

    if (vuln_dir / "headers_results.txt").exists():
        results["headers"] = (vuln_dir / "headers_results.txt").read_text()
    if (vuln_dir / "cors_results.txt").exists():
        results["cors"] = (vuln_dir / "cors_results.txt").read_text()
    if (vuln_dir / "dirs_found.txt").exists():
        results["directories"] = (vuln_dir / "dirs_found.txt").read_text()

    # Deep
    deep_dir = output_dir / "deep"
    if (deep_dir / "secrets_found.txt").exists():
        results["secrets"] = (deep_dir / "secrets_found.txt").read_text()
    if (deep_dir / "xss_found.txt").exists():
        results["xss"] = (deep_dir / "xss_found.txt").read_text()
    if (deep_dir / "sqli_found.txt").exists():
        results["sqli"] = (deep_dir / "sqli_found.txt").read_text()

    return results


# ============================================================
# ANÁLISE PRINCIPAL
# ============================================================

def analyze(target: str, output_dir: Path) -> dict:
    print(f"[+] Carregando resultados de scan para: {target}")
    scan_results = load_scan_results(output_dir)

    if not scan_results:
        print("[-] Nenhum resultado de scan encontrado. Execute as fases de scanning primeiro.")
        sys.exit(1)

    # Montar dados para o prompt
    scan_summary = json.dumps(scan_results, indent=2, ensure_ascii=False)

    # Carregar prompt template
    prompt_file = Path(__file__).parent.parent / "prompts" / "vulnerability_analysis.md"
    prompt_template = prompt_file.read_text(encoding="utf-8")
    prompt = prompt_template.replace("{SCAN_RESULTS}", scan_summary[:50000])  # Limitar tamanho

    print(f"[*] Enviando para IA ({AI_PROVIDER})...")
    response = call_ai(prompt)

    # Tentar parsear como JSON
    try:
        # Extrair JSON da resposta (a IA pode incluir texto antes/depois)
        start = response.find("{")
        end = response.rfind("}") + 1
        if start >= 0 and end > start:
            report = json.loads(response[start:end])
        else:
            report = {"raw_analysis": response}
    except json.JSONDecodeError:
        report = {"raw_analysis": response}

    report["target"] = target
    report["scan_date"] = datetime.now().isoformat()
    report["ai_provider"] = AI_PROVIDER

    # Salvar relatório
    report_path = output_dir / "reports" / "phase1_analysis.json"
    report_path.parent.mkdir(exist_ok=True)
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")

    print(f"[+] Relatório Fase 1 salvo em: {report_path}")
    return report


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 analyze.py <target_domain>")
        sys.exit(1)

    target = sys.argv[1]
    base_dir = Path(__file__).parent.parent.parent
    output_dir = base_dir / "output"

    report = analyze(target, output_dir)

    # Output JSON para n8n
    vulns = report.get("vulnerabilities", [])
    critical = sum(1 for v in vulns if v.get("severity") == "critical")
    high = sum(1 for v in vulns if v.get("severity") == "high")
    print(json.dumps({
        "phase": "ai_analysis",
        "step": "phase1",
        "target": target,
        "total_vulns": len(vulns),
        "critical": critical,
        "high": high,
        "report_file": str(output_dir / "reports" / "phase1_analysis.json")
    }))
