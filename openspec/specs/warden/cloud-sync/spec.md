# warden/cloud-sync Specification

## Purpose
Enables email-based warden authentication and the ability to backup and restore hostel configurations (rooms, students, face embeddings) to the cloud, allowing wardens to securely hand off duties to covering staff on different devices.

## Requirements

### Requirement: Warden Authentication
The system SHALL require wardens to authenticate using an email and password before accessing the home screen. During initial registration, the system SHALL also require the warden's Name, Hostel Name, Block Name, and Floor Number.

#### Scenario: Successful login
- **WHEN** a warden provides valid credentials
- **THEN** they are granted access to the home screen and their local database is initialized.

### Requirement: Warden Profile Display
The system SHALL display the warden's assigned Hostel Name and Floor Number on the home screen. The system SHALL also provide a Profile section that displays all collected registration details (Name, Hostel, Block, Floor).

#### Scenario: Viewing profile info
- **WHEN** the warden logs in and views the home screen or profile section
- **THEN** the system displays the cached profile data retrieved from the backend.

### Requirement: Backup configuration to cloud
The system SHALL allow an authenticated warden to explicitly back up their entire local configuration (rooms, students, and face embeddings) to the remote backend.

#### Scenario: Manual backup
- **WHEN** the warden initiates a cloud backup
- **THEN** all local rooms, students, and associated face embeddings are serialized and pushed to the backend, keyed by the warden's email.

### Requirement: Restore configuration from cloud
The system SHALL allow an authenticated warden to explicitly download their cloud configuration, overwriting the local database with the cloud copy.

#### Scenario: Manual restore
- **WHEN** the warden initiates a cloud restore
- **THEN** the system downloads the latest configuration associated with their email, drops the current local configuration, and populates the local database with the downloaded rooms, students, and face embeddings.
