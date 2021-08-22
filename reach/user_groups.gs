function update_ossoff_user_groups() {
  let sheet =
    SpreadsheetApp
       .openById(CONFIG["ossoff"]["spreadsheet_ids"]["user_groups"]);
  
  let user_ids = 
      sheet
       .getRange('A2:A')
       .getValues()
       .flat();
  let user_group_ids = 
      sheet
       .getRange('B2:B')
       .getValues()
       .flat();
  
  var user2group = {};
  user_ids.forEach((user_id, i) => user2group[user_id] = user_group_ids[i]);
  var group2users = reverse_mapping(user2group);
  
  Object.keys(group2users).forEach(function(user_group_id) {
    update_group(user_group_id, group2users[user_group_id])
  })
  
  Logger.log(fetch_groups());
}

function update_group(user_group_id, user_ids) {
  var payload = {
    "users": user_ids.map(function(user_id) { return {"user_id": user_id}; })
  };
  var res = reach_put("ossoff", "user_groups/" + user_group_id, payload); 
  Logger.log(res);
}


function fetch_groups(org = "ossoff") {
  reach_get(org, "user_groups")["user_groups"].map(function(group) { 
    return group["name"] + ": " + group["users"].length; 
  })
}
