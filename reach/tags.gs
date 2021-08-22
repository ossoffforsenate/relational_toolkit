let CHUNK_SIZE = 1000;

let ADD_TAG    = 1;
let REMOVE_TAG = 2;

function on_timer() {
  update_tags_for_org();
}

// Updates the Early Vote tags for all Reach orgs.
function update_all_orgs() {
  Object.keys(CONFIG).forEach(function(org) {
    update_tags_for_org(org)
  })
}

function update_ossoff_early_voted() {
  update_tags_for_org("ossoff", "early_voted") 
}

function update_ossoff_ballot_received() {
  update_tags_for_org("ossoff", "ballot_received") 
}

function update_ossoff_ballot_mailed() {
  update_tags_for_org("ossoff", "ballot_mailed") 
}

function update_ossoff_request_received() {
  update_tags_for_org("ossoff", "request_received") 
}

// Updates tags for given Reach organization.
function update_tags_for_org(org, spreadsheet_name) {
  let sheet =
    SpreadsheetApp
       .openById(CONFIG[org]["spreadsheet_ids"][spreadsheet_name]);
  
  let voter_ids = 
      sheet
       .getRange('A2:A')
       .getValues()
       .flat();
  let tags = 
      sheet
       .getRange('B2:B')
       .getValues()
       .flat();
  
  // For some reason empty spreadsheets have length 1 (not 0), for range A2:A...
  // Anyways, this is VERY hacky. But basically want it to exit early so
  // we don't run into an error later.
  if (voter_ids.length < 2) {
    return; 
  }
    
  // Group by tag voter statuses
  // then do below for each group
  var id2tag = {};
  voter_ids.forEach((voter_id, i) => id2tag[voter_id] = tags[i]);
  var tag2ids = reverse_mapping(id2tag);
  
  Object.keys(tag2ids).forEach(function(tag) {
    tag_voters(org, tag, tag2ids[tag])
  })
}

function tag_voters(org, tag, voter_ids) {
  Logger.log("Tagging voters with status " + tag);
  for (var i = 0; i < voter_ids.length; i += CHUNK_SIZE) {
    Logger.log(
      "On chunk " + (Math.floor(i / CHUNK_SIZE) + 1) + 
      " of " + Math.ceil(voter_ids.length / CHUNK_SIZE)
    );
    var voter_ids_slice = voter_ids.slice(i, i + CHUNK_SIZE);
    update_tag(org, voter_ids, tag, ADD_TAG);
    Logger.log("Tagged " + (i + voter_ids_slice.length) + "/" + voter_ids.length + " voters");
  } 
}

// Source: https://stackoverflow.com/questions/45728226/javascript-map-value-to-keys-reverse-object-mapping
const reverse_mapping = o => Object.keys(o).reduce((r, k) =>
        Object.assign(r, { [o[k]]: (r[o[k]] || []).concat(k) }), {})

// Updates the given tag (by adding or removing, depending on `action`) for the given people.
function update_tag(org, voter_ids, tag_name, action) {
  var people_payload = build_people_payload(org, voter_ids, action);
  var payload = {
    "name" : CONFIG[org]["tags"][tag_name]["name"],
    "locked": true,
    "people": people_payload
  };
  var res = reach_put(org, "tags/" + CONFIG[org]["tags"][tag_name]["id"], payload); 
  
  var voter_ids_success = res["people"].filter(function(person) {
    return person["status"] == "success";
  }).map(function(person) {
    return person["person_id"];
  });
  
  // If none were successful, don't try to log anything.
  // (If we do we'll generate an invalid SQL query.)
  if (voter_ids_success.length > 0) {
    log_tagged_to_bq(org, voter_ids_success, tag_name);
  }
}

// Builds payload for tag updates
function build_people_payload(org, voter_ids, action) {
  var people = [];
  for (var i = 0; i < voter_ids.length; i++) {
    people.push({
      "person_id": voter_ids[i],
      "person_id_type": CONFIG[org]["person_id_type"],
      "action": action == ADD_TAG ? "added" : "removed"
    });
  }
  return people;
}

function log_tagged_to_bq(org, voter_ids, tag_name) {
  var values = voter_ids.map(function(voter_id) {
    return "(\"" + voter_id + "\",\"" + tag_name + "\")"
  }).join(",");
  var request = {
    query: "INSERT INTO `" + CONFIG[org]["bq_log"]["table"] + "` values" + values,
    useLegacySql: false
  };
  BigQuery.Jobs.query(request, CONFIG[org]["bq_log"]["project_id"]);
}

function fetch_tags(org = "ossoff") {
    Logger.log(reach_get(org, "tags"))
}

