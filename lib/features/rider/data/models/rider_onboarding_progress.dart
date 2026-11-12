/// Presents the existing approval and activation states without granting access.
class RiderOnboardingProgress {
  const RiderOnboardingProgress({
    required this.title,
    required this.message,
    required this.nextActor,
    required this.currentStep,
    this.needsAttention = false,
  });

  final String title;
  final String message;
  final String nextActor;
  final int currentStep;
  final bool needsAttention;

  static const steps = [
    'Submitted',
    'Main Hub review',
    'Branch activation',
    'Rider workspace',
  ];

  factory RiderOnboardingProgress.fromJson(Map<String, dynamic> data) {
    final branch = data['branch'];
    final branchName = branch is Map
        ? branch['name']?.toString() ?? 'Assigned Branch'
        : 'Assigned Branch';
    final application = data['application_status'];
    final operations = data['operational_status'];
    if (operations == 'suspended') {
      return const RiderOnboardingProgress(
        title: 'Operations suspended',
        message:
            'Contact your Logistics Main Hub about the suspension. Main Hub must release it before Branch reactivation.',
        nextActor: 'Main Hub',
        currentStep: 2,
        needsAttention: true,
      );
    }
    if (application == 'rejected') {
      return const RiderOnboardingProgress(
        title: 'Application rejected',
        message:
            'Review the rejection reason below and contact your Logistics Main Hub.',
        nextActor: 'You and Main Hub',
        currentStep: 1,
        needsAttention: true,
      );
    }
    if (application == 'needs_documents') {
      return const RiderOnboardingProgress(
        title: 'Documents requested',
        message:
            'Upload the requested documents below so Main Hub can continue reviewing your application.',
        nextActor: 'You',
        currentStep: 1,
        needsAttention: true,
      );
    }
    if (data['can_operate'] == true) {
      return const RiderOnboardingProgress(
        title: 'Ready to work',
        message:
            'Your Branch has activated you for pickup and delivery. Open the Rider workspace to continue.',
        nextActor: 'You',
        currentStep: 3,
      );
    }
    if (application == 'approved' &&
        data['assignment_confirmation_required'] == true) {
      return const RiderOnboardingProgress(
        title: 'Confirm your assigned Branch',
        message:
            'Main Hub assigned a different Branch. Review and accept its coverage below before Branch activation.',
        nextActor: 'You',
        currentStep: 2,
        needsAttention: true,
      );
    }
    if (application == 'approved' && operations == 'inactive') {
      return RiderOnboardingProgress(
        title: 'Rider inactive',
        message:
            'Your Branch must review your coverage and reactivate you before you can resume operations.',
        nextActor: branchName,
        currentStep: 2,
        needsAttention: true,
      );
    }
    if (application == 'approved') {
      return RiderOnboardingProgress(
        title: 'Awaiting Branch activation',
        message:
            'Approved by Main Hub. Your assigned Branch must confirm your official barangays and activate you.',
        nextActor: branchName,
        currentStep: 2,
      );
    }
    return RiderOnboardingProgress(
      title: application == 'under_review'
          ? 'Main Hub is reviewing your application'
          : 'Awaiting Main Hub review',
      message:
          'Your selected Logistics Main Hub reviews your application and confirms the assigned Branch.',
      nextActor: 'Main Hub',
      currentStep: 1,
    );
  }
}
