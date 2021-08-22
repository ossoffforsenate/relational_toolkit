import requests
import pandas as pd

reach_api_username = ""
reach_api_password = ""

def main():
    token = requests.post("https://api.reach.vote/oauth/token", {
        "username": reach_api_username,
        "password": reach_api_password
    }).json()["access_token"]

    make_group("NAME OF GROUP HERE", token)

def make_group(name, token):
    endpoint = "https://api.reach.vote/api/v1/user_groups"
    result = requests.post(
        endpoint, 
        json = {
            "name": name
        }, 
        headers = {"Authorization": "Bearer " + token}
    )
    print(result.json())

if __name__ == "__main__":
    main()

