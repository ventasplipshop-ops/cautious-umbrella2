import json
import os
import google.generativeai as genai


genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

model = genai.GenerativeModel(
    "gemini-2.5-flash",
    generation_config={
        "temperature": 0.2,
        "max_output_tokens": 2048
    }
)

PROMPT = """
You are a market intelligence query generator.

Your job is to generate Google search queries that help analyze a company.

Return ONLY valid JSON.

Company name:
{company}

Generate 3 categories of queries:

1) identity_queries
Queries that help identify:
- company structure
- employees
- executives
- procurement
- operations leaders
- linkedin company page

2) situation_queries
Queries that reveal the current situation:
- news
- growth
- layoffs
- acquisitions
- expansion
- funding
- bankruptcy

3) needs_queries
Queries that reveal operational needs:
- hiring signals
- technology adoption
- supply chain issues
- logistics
- inventory
- ERP systems

Also provide:

roles_to_detect:
relevant roles to identify inside the company.

risk_signals:
signals that may indicate financial or operational problems.

Return JSON only with this structure:

{{
  "identity_queries": [],
  "situation_queries": [],
  "needs_queries": [],
  "roles_to_detect": [],
  "risk_signals": []
}}
"""

def run(seed):

    company = seed.company_name

    prompt = PROMPT.replace("{company}", company)

    response = model.generate_content(prompt)

    text = response.text.strip()

    # limpiar markdown
    if text.startswith("```"):
        text = text.split("```")[1]

    if text.startswith("json"):
        text = text[4:]

    text = text.strip()

    try:
        data = json.loads(text)

        required_keys = [
            "identity_queries",
            "situation_queries",
            "needs_queries",
            "roles_to_detect",
            "risk_signals"
        ]

        for key in required_keys:
            if key not in data:
                raise ValueError(f"Gemini response missing key: {key}")

    except Exception:
        raise ValueError("Gemini returned invalid JSON:\n" + text)

    # DEBUG
    print("\n[debug] query generation result")
    print(json.dumps(data, indent=2, ensure_ascii=False))
    print()

    return data