package corporate_action

import future.keywords.if
import future.keywords.in

default allow = false

# Main entry point for validation
allow if {
	# Check if the input is a valid corporate action submission
	is_corporate_action_submission(input)
	# Apply all validation rules
	count(deny) == 0
}

# Rule to deny submissions with validation errors
deny[msg] {
	# Field-level validation rules
	not validate_isin_format(input.payload.underlyingSecurity.isin)
	msg := "Invalid ISIN format"
}

deny[msg] {
	# Cross-field validation rules
	not validate_dates(input.payload.corporateActionDetails.dates)
	msg := "Ex-date must be after announcement date"
}

deny[msg] {
	# Submission-level validation rules
	not validate_default_option(input.payload)
	msg := "Mandatory events must have a default option"
}

# Helper function to check if the submission is a corporate action
is_corporate_action_submission(submission) {
	submission.header.submissionType == "CORPORATE_ACTION"
}

# --- Field-level validation functions ---

# Validate ISIN format (2 letters, 9 alphanumeric, 1 digit)
validate_isin_format(isin) {
	re_match("^[A-Z]{2}[A-Z0-9]{9}[0-9]$", isin)
}

# --- Cross-field validation functions ---

# Validate that ex-date is after announcement date
validate_dates(dates) {
	dates.exDate > dates.announcementDate
}

# --- Submission-level validation functions ---

# Validate that mandatory events have a default option
validate_default_option(payload) {
	payload.corporateActionGeneralInformation.mandatoryVoluntaryEventType != "MAND"
}
validate_default_option(payload) {
	payload.corporateActionGeneralInformation.mandatoryVoluntaryEventType == "MAND"
	some i
	payload.options[i].defaultOption == true
}
