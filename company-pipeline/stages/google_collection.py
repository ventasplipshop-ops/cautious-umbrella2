from ddgs import DDGS
from timing import human_delay


def search(query, limit=5):

    results = []

    try:
        with DDGS() as ddgs:
            for r in ddgs.text(query, max_results=limit):

                results.append({
                    "title": r.get("title"),
                    "url": r.get("href"),
                    "snippet": r.get("body")
                })

    except Exception as e:
        print("[search error]", e)

    return results


def run(seed, queries):

    print("[stage] google signal collection")

    signals = {
        "identity": [],
        "situation": [],
        "needs": []
    }

    # identity
    for q in queries["identity_queries"]:

        print("[query identity]", q)

        human_delay("short")

        signals["identity"].extend(search(q))


    # situation
    for q in queries["situation_queries"]:

        print("[query situation]", q)

        human_delay("short")

        signals["situation"].extend(search(q))


    # needs
    for q in queries["needs_queries"]:

        print("[query needs]", q)

        human_delay("short")

        signals["needs"].extend(search(q))


    return signals