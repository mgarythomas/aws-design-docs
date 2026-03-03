package corporate_action

import future.keywords.if

# --- Test Cases ---

# Test case 1: Valid submission should be allowed
test_allow_valid_submission if {
	allow with input as {
		"header": {"submissionType": "CORPORATE_ACTION"},
		"payload": {
			"underlyingSecurity": {"isin": "AU000000BHP4"},
			"corporateActionDetails": {
				"dates": {
					"announcementDate": "2024-10-15",
					"exDate": "2024-11-01"
				}
			},
			"corporateActionGeneralInformation": {
				"mandatoryVoluntaryEventType": "VOLU"
			}
		}
	}
}

# Test case 2: Invalid ISIN format should be denied
test_deny_invalid_isin if {
	results := deny with input as {
		"header": {"submissionType": "CORPORATE_ACTION"},
		"payload": {
			"underlyingSecurity": {"isin": "INVALIDISIN"},
			"corporateActionDetails": {
				"dates": {
					"announcementDate": "2024-10-15",
					"exDate": "2024-11-01"
				}
			},
			"corporateActionGeneralInformation": {
				"mandatoryVoluntaryEventType": "VOLU"
			}
		}
	}
	results == {"Invalid ISIN format"}
}

# Test case 3: Invalid dates should be denied
test_deny_invalid_dates if {
	results := deny with input as {
		"header": {"submissionType": "CORPORATE_ACTION"},
		"payload": {
			"underlyingSecurity": {"isin": "AU000000BHP4"},
			"corporateActionDetails": {
				"dates": {
					"announcementDate": "2024-11-01",
					"exDate": "2024-10-15"
				}
			},
			"corporateActionGeneralInformation": {
				"mandatoryVoluntaryEventType": "VOLU"
			}
		}
	}
	results == {"Ex-date must be after announcement date"}
}

# Test case 4: Mandatory event without default option should be denied
test_deny_mandatory_event_without_default_option if {
	results := deny with input as {
		"header": {"submissionType": "CORPORATE_ACTION"},
		"payload": {
			"underlyingSecurity": {"isin": "AU000000BHP4"},
			"corporateActionDetails": {
				"dates": {
					"announcementDate": "2024-10-15",
					"exDate": "2024-11-01"
				}
			},
			"corporateActionGeneralInformation": {
				"mandatoryVoluntaryEventType": "MAND"
			},
			"options": [{"defaultOption": false}]
		}
	}
	results == {"Mandatory events must have a default option"}
}

# Test case 5: Non-corporate action submission should be denied
test_deny_non_corporate_action if {
	not allow with input as {"header": {"submissionType": "OTHER"}}
}
