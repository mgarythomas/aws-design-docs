# Implementation Plan

- [x] 1. Set up core type definitions and common validation schemas
  - Create `lib/types/forms.ts` with FormSubmission, FormDelta, and StoredFormDraft interfaces
  - Create `lib/types/api.ts` with ApiError interface
  - Create `lib/schemas/common.schema.ts` with reusable Zod schemas (ABN, ARSN, positive number, share class)
  - _Requirements: 2.1, 2.2, 3.1_

- [x] 2. Implement buy-back form Zod schema with validation rules
  - Create `lib/schemas/buy-back.schema.ts` with complete buy-back form schema
  - Define buy-back type enum and conditional section schemas (on-market, employee share scheme, selective, equal access)
  - Implement cross-field validation using Zod refinements to ensure conditional sections match selected buy-back type
  - Export TypeScript type derived from schema using z.infer
  - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.4, 3.5, 4.1, 4.2, 4.3, 4.4_

- [x] 2.1 Write unit tests for buy-back schema validation
  - Test valid buy-back data passes validation
  - Test ABN/ARSN format validation
  - Test conditional field requirements based on buy-back type
  - Test cross-field validation refinements
  - _Requirements: 2.1, 3.1, 3.2, 3.3_

- [x] 3. Create local storage utilities for draft persistence
  - Create `lib/storage/form-storage.ts` with functions to save, restore, and clear form drafts
  - Implement auto-save debouncing logic
  - Add error handling for storage quota exceeded
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 4. Implement version tracking system
  - Create `lib/storage/version-tracker.ts` with version management functions
  - Implement delta calculation function to compare form versions
  - Add functions to store and retrieve version history
  - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6_

- [x] 4.1 Write unit tests for version tracking
  - Test version increment logic
  - Test delta calculation for added, modified, and removed fields
  - Test version history retrieval
  - _Requirements: 11.1, 11.2, 11.3, 11.4_

- [x] 5. Create API client and form submission functions
  - Create `lib/api/client.ts` with authenticated API client
  - Create `lib/api/forms.ts` with submitForm function
  - Implement error handling for network failures, validation errors, and server errors
  - Add retry logic with exponential backoff for network failures
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 6. Build reusable form UI components
  - Create `components/forms/form-field-wrapper.tsx` for consistent field rendering with labels, errors, and help text
  - Create `components/forms/form-section.tsx` for grouping related fields with conditional visibility
  - Create `components/ui/form-progress.tsx` for visual progress indication
  - _Requirements: 7.1, 7.2, 7.3, 7.4_

- [x] 7. Implement compliance section component
  - Create `components/forms/compliance-section.tsx` with compliance statements and signature fields
  - Implement conditional display of trust vs company compliance statements
  - Add signature capture fields (name, role, date) with validation
  - _Requirements: 9.1, 9.2, 9.3, 9.4_

- [x] 8. Create buy-back form component with conditional sections
  - Create `components/forms/buy-back-form.tsx` with react-hook-form integration
  - Implement entity information section (name, ABN/ARSN)
  - Implement buy-back information section (type, share class, approval, reason)
  - Implement conditional sections using watch() for buy-back type changes
  - Wire up auto-save to local storage with debouncing
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 6.1, 8.1, 8.2, 8.3, 8.5_

- [x] 9. Implement on-market buy-back conditional section
  - Add on-market buy-back fields (broker name, maximum shares, time period, conditions) to buy-back form
  - Implement conditional rendering based on buy-back type selection
  - Add field clearing when section is hidden
  - _Requirements: 1.1, 4.1, 4.5, 4.6_

- [x] 10. Implement employee share scheme buy-back conditional section
  - Add employee share scheme fields (number of shares, price) to buy-back form
  - Implement conditional rendering based on buy-back type selection
  - Add field clearing when section is hidden
  - _Requirements: 1.1, 4.2, 4.5, 4.6_

- [x] 11. Implement selective buy-back conditional section
  - Add selective buy-back fields (person/class, number of shares, price) to buy-back form
  - Implement conditional rendering based on buy-back type selection
  - Add field clearing when section is hidden
  - _Requirements: 1.1, 4.3, 4.5, 4.6_

- [x] 12. Implement equal access scheme conditional section
  - Add equal access scheme fields (percentage, total shares, price, record date) to buy-back form
  - Implement conditional rendering based on buy-back type selection
  - Add field clearing when section is hidden
  - Integrate date picker component from UI package
  - _Requirements: 1.1, 4.4, 4.5, 4.6_

- [x] 13. Add form submission handling with validation
  - Implement onSubmit handler in buy-back form component
  - Create submission document with metadata (ID, timestamp, version)
  - Integrate API client for form submission
  - Add success and error toast notifications
  - Clear local storage draft on successful submission
  - _Requirements: 1.5, 2.1, 2.2, 5.1, 5.2, 5.3, 6.3, 9.5_

- [x] 14. Create form review component
  - Create `components/forms/form-review.tsx` to display completed form data in read-only format
  - Organize data by sections matching the form structure
  - Highlight active conditional sections based on buy-back type
  - Add Edit and Confirm buttons
  - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

- [x] 15. Create buy-back form page with routing
  - Create `app/forms/buy-back/page.tsx` with form page component
  - Initialize form with data from local storage if available
  - Implement navigation to review page
  - Add page metadata and layout
  - _Requirements: 1.1, 6.2, 8.1_

- [x] 16. Create review page with confirmation flow
  - Create `app/forms/buy-back/review/page.tsx` with review page component
  - Load form data from state or local storage
  - Integrate FormReview component
  - Implement Edit navigation back to form
  - Implement Confirm to trigger submission
  - _Requirements: 10.1, 10.2, 10.4, 10.5_

- [x] 17. Add form restoration from local storage on page load
  - Implement useEffect hook to restore draft data on component mount
  - Display notification when draft is restored
  - Add option to start fresh or continue with draft
  - _Requirements: 6.2, 6.5_

- [x] 18. Implement accessibility features
  - Add proper ARIA labels to all form fields
  - Ensure keyboard navigation works for all interactive elements
  - Add aria-invalid and aria-describedby for validation errors
  - Implement focus management for error states
  - Test with screen reader
  - _Requirements: 7.6_

- [x] 19. Add responsive layout and styling
  - Apply Tailwind CSS classes for responsive design
  - Ensure form works on desktop and tablet viewports
  - Add visual grouping for form sections
  - Style validation errors consistently
  - Add loading states for submission
  - _Requirements: 7.1, 7.2, 7.3, 7.5_

- [x] 20. Create integration tests for buy-back form flow
  - Test complete form submission flow from start to finish
  - Test draft save and restore on page reload
  - Test conditional section visibility based on buy-back type
  - Test API error handling and retry logic
  - Test validation error display
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 4.5, 4.6, 5.2, 5.3, 6.1, 6.2_

- [x] 21. Create form configuration file for extensibility
  - Create `config/forms.ts` with form registry and metadata
  - Define form type constants and routing configuration
  - Add form-specific settings (auto-save interval, validation mode)
  - _Requirements: 8.4_

- [x] 22. Add form helper utilities
  - Create `lib/utils/form-helpers.ts` with utility functions
  - Implement UUID generation for submission IDs
  - Add date formatting utilities
  - Add form data transformation helpers
  - _Requirements: 2.2, 9.5_

- [x] 23. Add accessibility tests
  - Test keyboard navigation through form
  - Test screen reader announcements for errors
  - Test focus indicators visibility
  - Test ARIA label correctness
  - _Requirements: 7.6_
