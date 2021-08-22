import requests
import pandas as pd
import itertools

reach_api_username = ""
reach_api_password = ""

tag_id = "RJY829J8"
tag_name = "phoenix_uncontactable"

sos_ids_filename = ""

chunk_size = 1000

# Source: https://stackoverflow.com/questions/8991506/iterate-an-iterator-by-chunks-of-n-in-python
def grouper(n, iterable):
    it = iter(iterable)
    while True:
       chunk = tuple(itertools.islice(it, n))
       if not chunk:
           return
       yield chunk

def main():
    sos_ids = list(pd.read_csv(sos_ids_filename)["state_file_id"])

    for i, chunk in enumerate(grouper(chunk_size, sos_ids)):
        print("On chunk %d of %d" % (i, len(sos_ids)/chunk_size))
        people = build_people(chunk)
        payload = {
            "name": tag_name,
            "people": people
        }
        token = requests.post("https://api.reach.vote/oauth/token", {
            "username": reach_api_username,
            "password": reach_api_password
        }).json()["access_token"]

        endpoint = "https://api.reach.vote/api/v1/tags/" + tag_id
        result = requests.put(
            endpoint,
            json = payload,
            headers = {"Authorization":  "Bearer " + token}
        )
        print(result.json())

def build_people(people):
    return [{
        "person_id": p,
        "action": "added",
        "person_id_type": "State File ID"
    } for p in people]

if __name__ == "__main__":
    main()

