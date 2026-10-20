import json
from pipeline import run_pipeline

companies = [

    {
        "company_name": "Bilbaos",
        "country": "Argentina",
        "industry": None,
        "city": None
    }

]

results = []

for company in companies:

    print("---- analyzing", company["company_name"])

    result = run_pipeline(company)

    results.append(result)

print(json.dumps(results, indent=2, ensure_ascii=False))