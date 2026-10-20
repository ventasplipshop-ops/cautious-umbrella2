from dataclasses import asdict
from models.company import CompanySeed
from stages.identity_resolver import run as resolve_identity


def run_pipeline(company_data):

    seed = CompanySeed(**company_data)

    print("\n==============================")
    print("[pipeline] identity only")
    print("[company]", seed.company_name)
    print("==============================\n")

    identity = resolve_identity(seed)

    return {
        "company": seed.company_name,
        "seed": asdict(seed),
        "identity": identity
    }