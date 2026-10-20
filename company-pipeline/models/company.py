from dataclasses import dataclass, asdict


@dataclass
class CompanySeed:

    company_name: str
    country: str | None = None
    industry: str | None = None
    city: str | None = None
    website: str | None = None


@dataclass
class CompanyDiscovery:

    company_name: str
    linkedin_url: str | None
    employees: str | None
    top_profiles: list

    def to_json(self):
        return asdict(self)