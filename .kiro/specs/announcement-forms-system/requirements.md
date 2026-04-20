# Requirements Document

## Introduction

The announcements micro frontend application needs to capture structured announcement data through a series of forms based on existing ASX regulatory documents. The system will consist of 10 different form types that collect announcement information and submit it as JSON documents to a back-end API service. This initial phase focuses on implementing the buy-back announcement form (Appendix 3C) as an example implementation that will serve as a template for the remaining forms.

The forms must accurately capture all required fields from the source documents, provide appropriate validation, and structure the data in a format suitable for API submission and regulatory compliance.

## Requirements

### Requirement 1: Buy-Back Form Implementation

**User Story:** As a user submitting a buy-back announcement, I want to complete a structured form based on Appendix 3C, so that I can submit accurate buy-back information to ASX.

#### Acceptance Criteria

1. WHEN the user accesses the buy-back form THEN the system SHALL display all fields from Appendix 3C including entity information, buy-back details, and compliance statements
2. WHEN the user enters entity information THEN the system SHALL capture name, ABN/ARSN in structured fields
3. WHEN the user selects a buy-back type THEN the system SHALL display conditional sections relevant to that type (on-market, employee share scheme, selective, or equal access scheme)
4. WHEN the user completes the form THEN the system SHALL validate all required fields are populated before allowing submission
5. WHEN the user submits the form THEN the system SHALL structure the data as a JSON document matching the form schema

### Requirement 2: Form Data Structure and JSON Schema

**User Story:** As a back-end developer, I want form submissions to follow a consistent JSON schema, so that I can reliably process and store announcement data.

#### Acceptance Criteria

1. WHEN a form is submitted THEN the system SHALL generate a JSON document with a consistent top-level structure including metadata and form data
2. WHEN the JSON document is created THEN the system SHALL include form type identifier, submission timestamp, and version information
3. WHEN conditional sections are not applicable THEN the system SHALL either omit those fields or mark them as null in the JSON structure
4. WHEN the form includes multi-value fields THEN the system SHALL represent them as arrays in the JSON structure
5. IF the form schema changes THEN the system SHALL include a version number to support backward compatibility

### Requirement 3: Form Validation and Data Integrity

**User Story:** As a compliance officer, I want the form to validate data entry, so that submissions meet regulatory requirements and data quality standards.

#### Acceptance Criteria

1. WHEN defining form validation THEN the system SHALL use Zod schemas to define all validation rules with type safety
2. WHEN the user enters data in a required field THEN the system SHALL use Zod's required validation and display errors via react-hook-form
3. WHEN the user enters an ABN/ARSN THEN the system SHALL validate the format using a custom Zod refinement matching Australian business number standards
4. WHEN the user enters numeric values (share counts, prices) THEN the system SHALL use Zod number schemas with positive value constraints
5. WHEN the user enters a date THEN the system SHALL use Zod date validation integrated with the UI Calendar component
6. WHEN validation fails THEN the system SHALL display error messages from Zod schemas through react-hook-form's error handling
7. WHEN all validations pass THEN the system SHALL enable the submit button based on react-hook-form's formState.isValid

### Requirement 4: Conditional Form Sections

**User Story:** As a user completing a buy-back form, I want to see only the sections relevant to my buy-back type, so that I can efficiently complete the form without confusion.

#### Acceptance Criteria

1. WHEN the user selects "on-market buy-back" THEN the system SHALL display fields 9-13 (broker name, maximum shares, time period, conditions)
2. WHEN the user selects "employee share scheme buy-back" THEN the system SHALL display fields 14-15 (number of shares, price)
3. WHEN the user selects "selective buy-back" THEN the system SHALL display fields 16-18 (person/class, number of shares, price)
4. WHEN the user selects "equal access scheme" THEN the system SHALL display fields 19-22 (percentage, total shares, price, record date)
5. WHEN the user changes buy-back type THEN the system SHALL hide previously displayed conditional sections and show the new relevant sections
6. WHEN conditional sections are hidden THEN the system SHALL clear any data previously entered in those sections

### Requirement 5: API Integration

**User Story:** As a system administrator, I want forms to submit data to a back-end API, so that announcement data is centrally stored and processed.

#### Acceptance Criteria

1. WHEN the user submits a valid form THEN the system SHALL send a POST request to the configured API endpoint with the JSON document
2. WHEN the API request is successful THEN the system SHALL display a success message to the user
3. WHEN the API request fails THEN the system SHALL display an error message and allow the user to retry
4. WHEN submitting to the API THEN the system SHALL include appropriate authentication headers
5. WHEN the API is unavailable THEN the system SHALL provide a clear error message and optionally save the form data locally for later submission

### Requirement 6: Form State Management

**User Story:** As a user completing a long form, I want my progress to be saved, so that I don't lose data if I navigate away or experience a browser issue.

#### Acceptance Criteria

1. WHEN the user enters data in form fields THEN the system SHALL automatically save the form state to browser local storage
2. WHEN the user returns to an incomplete form THEN the system SHALL restore previously entered data from local storage
3. WHEN the user successfully submits a form THEN the system SHALL clear the saved form state from local storage
4. WHEN the user explicitly clears the form THEN the system SHALL remove the saved state and reset all fields
5. IF multiple forms are in progress THEN the system SHALL maintain separate state for each form type

### Requirement 7: User Interface and Experience

**User Story:** As a user, I want an intuitive and accessible form interface, so that I can efficiently complete announcements without errors.

#### Acceptance Criteria

1. WHEN the form loads THEN the system SHALL display fields in a logical order matching the source document structure
2. WHEN the user interacts with form fields THEN the system SHALL provide clear labels and help text where needed
3. WHEN the form has multiple sections THEN the system SHALL use visual grouping to organize related fields
4. WHEN the user completes a section THEN the system SHALL provide visual feedback indicating completion status
5. WHEN the form is displayed THEN the system SHALL be responsive and usable on desktop and tablet devices
6. WHEN the user navigates the form THEN the system SHALL support keyboard navigation and screen readers for accessibility

### Requirement 8: Form Template Architecture

**User Story:** As a developer, I want the buy-back form to serve as a reusable template, so that I can efficiently implement the remaining 9 announcement forms.

#### Acceptance Criteria

1. WHEN implementing the buy-back form THEN the system SHALL use react-hook-form for form state management and submission handling
2. WHEN defining form validation THEN the system SHALL use Zod schemas to define validation rules and type safety
3. WHEN rendering form fields THEN the system SHALL use components from the packages/ui component library (Input, Select, Calendar/DatePicker, etc.)
4. WHEN creating the form structure THEN the system SHALL separate form configuration (Zod schemas, field definitions) from rendering logic
5. WHEN implementing conditional logic THEN the system SHALL use react-hook-form's watch functionality and conditional rendering
6. WHEN building validation THEN the system SHALL create reusable Zod schemas that can be composed and shared across forms

### Requirement 9: Compliance and Audit Trail

**User Story:** As a compliance officer, I want submission records to include compliance statements and signatures, so that we maintain regulatory compliance and audit trails.

#### Acceptance Criteria

1. WHEN the user reaches the compliance section THEN the system SHALL display the required compliance statements from the source document
2. WHEN the user signs the form THEN the system SHALL capture the signatory name, role (Director/Company Secretary), and date
3. WHEN the form is submitted THEN the system SHALL include the compliance statements and signature information in the JSON document
4. WHEN the signature is captured THEN the system SHALL validate that all required signature fields are completed
5. WHEN the JSON document is created THEN the system SHALL include a unique submission identifier for audit purposes

### Requirement 10: Form Preview and Review

**User Story:** As a user, I want to review my completed form before submission, so that I can verify all information is correct.

#### Acceptance Criteria

1. WHEN the user completes all required fields THEN the system SHALL provide a "Review" option before final submission
2. WHEN the user enters review mode THEN the system SHALL display all entered data in a read-only format organized by section
3. WHEN reviewing the form THEN the system SHALL clearly indicate which buy-back type was selected and show only relevant sections
4. WHEN in review mode THEN the system SHALL provide an "Edit" option to return to the form and make changes
5. WHEN the user confirms the review THEN the system SHALL proceed to final submission

### Requirement 11: Version Management and Change Tracking

**User Story:** As a compliance officer, I want to track all changes made to saved form data, so that I can maintain an audit trail and understand the evolution of each announcement.

#### Acceptance Criteria

1. WHEN a form is initially saved THEN the system SHALL create version 1 with the complete form data
2. WHEN a user modifies and saves a previously saved form THEN the system SHALL increment the version number
3. WHEN changes are saved THEN the system SHALL calculate and store the delta (differences) between the previous version and the current version
4. WHEN storing the delta THEN the system SHALL capture which fields were added, modified, or removed with their old and new values
5. WHEN the delta is created THEN the system SHALL include metadata such as timestamp, user identifier, and version numbers
6. WHEN retrieving form history THEN the system SHALL provide access to all versions and their associated deltas
7. WHEN the API receives an update THEN the system SHALL send both the complete current form data and the delta from the previous version
8. WHEN displaying form history THEN the system SHALL show a timeline of changes with the ability to view what changed in each version
