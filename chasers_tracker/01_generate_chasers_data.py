from faker import Faker
import random
import pandas as pd
import json

# From real CM data. Already had this template, so didn't make one for vols, for simplicity.
# Script in `cm_tracker` directory.
cm_distribution = pd.read_csv("cm_topline_cm_template.csv")

fake = Faker()
plan_detail_samples = [
    "Carpooling with brothers and using drivers license",
    "Going together in the morning using our drivers licenses",
    "Planning to go with parents that morning, using drivers license",
    "Going with mother in the morning, will call me if anything happens or needs help, using drivers license",
    "Going with fiancé in the morning, using drivers licenses",
    "Voting with friends on the 5th !!",
    "We’re carpooling together that morning and using our drivers licenses.",
    "Did mail-in voting",
    "Carpooling with brothers and using drivers license",
    "Going with his partner in the morning with drivers license !",
    "Absentee",
    "Will try to get in early at the arena this week but not sure she can with her work schedule",
    "State ID, will go with family",
    "Voting with drivers license on Jan 5",
    "Plans to bring drivers license to vote in person on Jan 5.",
    "Jan 5 with drivers license",
    "Sending absentee ballot back",
    "Going to return ballot soon",
    "Plans to go Jan 5 with drivers license",
    "She is out of country.",
    "Planning on going this week",
    "Wants to go Jan 5 with drivers license",
    "Is currently in isolation so she voted by mail.",
    "Early voted yesterday.",
    "Voted early",
    "Voting on Election Day",
    "Ga ID",
    "Ga drivers license",
    "Unsure when she will go today.",
    "Vague response. Drop off ballot",
    "will be going on election day in the evening",
    "Going After work",
    "Won’t vote because it’s a waste of time 😩"
]

def generate_vols(n):
    print("Generating %d Vols." % n)
    return {"users": [generate_vol() for i in range(n)]}
    
def generate_vol():
    cm_sample = cm_distribution.sample(1)
    state = random.choices(["GA", fake.state_abbr()], weights = [70, 30])[0]
    zipcode = fake.postalcode_in_state(state_abbr = state)
    return {
        "user_id": fake.hexify(text = "^"*8).upper(),
        "user_name": fake.name(),
        "phone_number": fake.numerify(text = "%" + "#"*9),
        "date_joined": cm_sample.iloc[0, 0],
        "zip_code": zipcode,
        "state": state,
        "network": generate_network(cm_sample.iloc[0, 1], cm_sample.iloc[0, 2])
    }
    
def generate_network(voters, reach_adds):
    if voters + reach_adds == 0:
        reach_adds = 1
    print("Generating network with %d matched voters, %d reach adds." % (voters, reach_adds))
    return [generate_single_voter(matched_voter = True) for _ in range(voters)] + \
        [generate_single_voter(matched_voter = False) for _ in range(reach_adds)]

def generate_single_voter(matched_voter = True):
    support_id_number = random.choices(["1", "2", "3", "4", "5", ""], weights = [30, 10, 4, 1.1, 1.1, 61])[0]
    tier_number = random.choices(["1", "2", "3", "4"], weights = [15, 8, 12, 4])[0] if matched_voter else "4"
    voting_status = random.choices(
        ["Has Voted!", "Needs to Return Ballot", "Needs to Vote"], 
        weights = [50, 20, 40]
    )[0] if matched_voter else ""
    return {
        "reach_id": fake.numerify(text = "%" + "#"*9),
        "auto_applied_tag": "Voter" if matched_voter else "Reach Add",
        "person_first_name": fake.first_name(),
        "person_last_name": fake.last_name(),
        "support_id": {
            "1":  "Strongly supporting Jon & Warnock",
            "2": "Leaning Jon & Warnock",
            "3": "Undecided",
            "4": "Lean Perdue",
            "5": "Strongly supporting Perdue",
            "": ""
        }[support_id_number],
        "vote_plan": random.choices(
            ["Already Voted", "At the polls Tues, January 5", "Drop off mail in ballot", "Early in-person", "Not sure", ""],
            weights = [41, 25, 8, 15, 1, 60]
        )[0],
        "detailed_plan": random.choices([random.choice(plan_detail_samples), ""], weights = [40, 60])[0],
        "vol_ask": random.choices(["Yes", "No", ""], weights = [7, 32, 117])[0],
        "voting_status": voting_status,
        "only_reachable_by_reacher": random.choices(["y", "n"], weights = [10, 90])[0],
        "triplers": random.choices(["\n".join([fake.name() for _ in range(3)]), ""], [6.5, 145])[0],
        "tier": tier_number,
    }
    
with open("chasers_data.json", "w") as f:
    json.dump(generate_vols(500), f)
