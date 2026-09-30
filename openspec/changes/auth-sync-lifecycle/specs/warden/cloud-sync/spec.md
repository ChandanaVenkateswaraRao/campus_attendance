# Spec Delta

## MODIFIED Requirements

### Requirement: Warden Authentication
The system SHALL require wardens to authenticate using an email and password before accessing the home screen. During initial registration, the system SHALL also require the warden's Name, Hostel Name, Block Name, and Floor Number. When a warden successfully logs in, the system SHALL automatically restore their configuration from the cloud.

#### Scenario: Successful login
- **WHEN** a warden provides valid credentials
- **THEN** the system fetches their auth token and automatically downloads the latest configuration from the cloud, displaying a sync progress indicator before granting access to the home screen.

### Requirement: Backup configuration to cloud
The system SHALL require the warden's entire local configuration to be synced and backed up to the remote backend automatically when they log out.

#### Scenario: Automatic backup on logout
- **WHEN** the warden initiates a logout
- **THEN** all local rooms, students, and face embeddings are serialized and pushed to the backend, keyed by the warden's email.

#### Scenario: Blocked logout on network failure
- **WHEN** the warden initiates a logout without a network connection
- **THEN** the backup fails, the logout is blocked, and the system alerts the user that a network connection is required to safely log out.

## ADDED Requirements

### Requirement: Secure Local Wipe on Logout
The system SHALL completely wipe the local configuration database (rooms, students, face embeddings, attendance records) after a successful cloud backup during logout to ensure no sensitive data remains on the device.

#### Scenario: Post-logout data wipe
- **WHEN** the automatic backup succeeds during logout
- **THEN** the local database is cleared and the warden's authentication token is removed, returning them to the login screen.

## REMOVED Requirements

### Requirement: Restore configuration from cloud
**Reason**: Restoration now happens automatically on login rather than manually.
**Migration**: See the modified "Warden Authentication" requirement.
