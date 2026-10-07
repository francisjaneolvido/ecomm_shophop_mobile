enum RegistrationRole {
  buyer,
  seller,
  rider,
}

extension RegistrationRoleUi on RegistrationRole {
  String get eyebrow {
    switch (this) {
      case RegistrationRole.buyer:
        return 'EMAIL VERIFICATION';
      case RegistrationRole.seller:
        return 'SELLER VERIFICATION';
      case RegistrationRole.rider:
        return 'RIDER VERIFICATION';
    }
  }

  String get title {
    switch (this) {
      case RegistrationRole.buyer:
        return 'Verify your email';
      case RegistrationRole.seller:
        return 'Verify your seller email';
      case RegistrationRole.rider:
        return 'Verify your rider email';
    }
  }

  String get subtitle {
    switch (this) {
      case RegistrationRole.buyer:
        return 'Enter the 6-digit code we sent to your registered email address.';
      case RegistrationRole.seller:
        return 'Enter the 6-digit code we sent to your seller email address.';
      case RegistrationRole.rider:
        return 'Enter the 6-digit code we sent to your rider email address.';
    }
  }

  String get verifyButtonLabel {
    switch (this) {
      case RegistrationRole.buyer:
        return 'Verify Email';
      case RegistrationRole.seller:
        return 'Verify Seller Email';
      case RegistrationRole.rider:
        return 'Verify Rider Email';
    }
  }

  String get approvalMessage {
    switch (this) {
      case RegistrationRole.buyer:
        return 'After verification, your registration will wait for administrator approval.';
      case RegistrationRole.seller:
        return 'After verification, your seller application and documents will wait for administrator review.';
      case RegistrationRole.rider:
        return 'After verification, your rider application will wait for Logistics / Sorting Center approval.';
    }
  }
}
