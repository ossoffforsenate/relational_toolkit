from collections import defaultdict
import datetime
from faker import Faker
import json
import random
import pandas as pd

# From real CM data: date_joined, # voters, # reach_adds
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

def generate_pods(n):
    print("Generating %d pods." % n)
    return dict(zip(
        map(
            lambda pod: "Pod " + chr(pod) + " // " + fake.first_name(), 
            range(ord("A"), ord("A") + n)
        ),
        [generate_rmms(random.randint(8, 9)) for i in range(n)]
    ))

def generate_rmms(n):
    print("Generating %d RMMs." % n)
    return [{
        "rmm": fake.name(),
        "cms": generate_cms(random.randint(70, 100))
    } for _ in range(n)]

def generate_cms(n):
    print("Generating %d CMs." % n)
    cm_samples = [cm_distribution.sample(1) for _ in range(n)]
    return [{
        "user_id": fake.hexify(text = "^"*8).upper(),
        "date_joined": cm_samples[i].iloc[0, 0],
        "user_name": fake.name(),
        "email_address": fake.ascii_email(),
        "phone_number": fake.numerify(text = "%" + "#"*9),
        "last_activity": random.choices(["0","1","2","3","4","5","6","7","8","9"], [15,10,20,15,5,10,10,5,5,5])[0],
        "voting_status": random.choices(["Has Voted!", "Needs to Return Ballot", "Needs to Vote", "Unable to match to voter file"], [40, 15, 25, 20])[0],
        "network": generate_network(cm_samples[i].iloc[0, 1], cm_samples[i].iloc[0, 2])
    } for i in range(n)]

def generate_network(voters, reach_adds):
    print("Generating network with %d matched voters, %d reach adds." % (voters, reach_adds))
    return [generate_single_voter(matched_voter = True) for _ in range(voters)] + \
        [generate_single_voter(matched_voter = False) for _ in range(reach_adds)]

def generate_single_voter(matched_voter = True):
    support_id_number = random.choices(["1", "2", "3", "4", "5", ""], weights = [30, 10, 4, 1.1, 1.1, 61])[0]
    sos_id = fake.numerify("#" * 8) if matched_voter else "Reach Add"
    tier_number = random.choices(["1", "2", "3", "4"], weights = [15, 8, 12, 4])[0] if matched_voter else "4"
    voting_status = random.choices(
        ["Has Voted!", "Needs to Return Ballot", "Needs to Vote"], 
        weights = [50, 20, 40]
    )[0] if matched_voter else ""
    return {
        "voter": fake.name(),
        "support_id": {
            "1":  "Strongly supporting Jon & Warnock",
            "2": "Leaning Jon & Warnock",
            "3": "Undecided",
            "4": "Lean Perdue",
            "5": "Strongly supporting Perdue",
            "": ""
        }[support_id_number],
        "support_id_numeric": support_id_number,
        "vote_plan": random.choices(
            ["Already Voted", "At the polls Tues, January 5", "Drop off mail in ballot", "Early in-person", "Not sure", ""],
            weights = [41, 25, 8, 15, 1, 60]
        )[0],
        "detailed_plan": random.choices([random.choice(plan_detail_samples), ""], weights = [40, 60])[0],
        "vol_ask": random.choices(["Yes", "No", ""], weights = [7, 32, 117])[0],
        "triplers": random.choices(["\n".join([fake.name() for _ in range(3)]), ""], [6.5, 145])[0],
        "outreach": random.choices(["Do not Contact Again", "Mark to Contact Again", "Skip voter", ""], [10, 3, 1.3, 140])[0],
        "sos_id": sos_id,
        "tier": tier_number,
        "tier_str": {
            "1": "Tier 1",
            "2": "Tier 2",
            "3": "Tier 3",
            "4": "Not a Target"
        }[tier_number],
        "voting_status": voting_status
    }

with open("cm_data.json", "w") as f:
    json.dump(generate_pods(4), f)
