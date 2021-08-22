let API_URL = "https://api.reach.vote/api/v1/"

function get_token(org) {
  var payload = CONFIG[org]["credentials"];
  var options =
   {
     "method" : "post",
     "payload" : payload,
     "followRedirects" : false
   };
  return JSON.parse(UrlFetchApp.fetch("https://api.reach.vote/oauth/token" , options))["access_token"];
}

function reach_get(org, endpoint) {
  var options = {
    "method" : "get",
    "headers": {"Authorization":  "Bearer " + get_token(org)}
  }
  return JSON.parse(UrlFetchApp.fetch(API_URL + endpoint, options))
}

function reach_put(org, endpoint, payload) {
  var options = {
    "method" : "put",
    "contentType" : "application/json",
    "payload" : JSON.stringify(payload),
    "headers": {"Authorization":  "Bearer " + get_token(org)}
  };
  return JSON.parse(UrlFetchApp.fetch(API_URL + endpoint, options));
}
 
function reach_post(org, endpoint, payload) {
  var options = {
    "method" : "post",
    "contentType" : "application/json",
    "payload" : JSON.stringify(payload),
    "headers": {"Authorization":  "Bearer " + get_token(org)}
  };
  return JSON.parse(UrlFetchApp.fetch(API_URL + endpoint, options));
}
 