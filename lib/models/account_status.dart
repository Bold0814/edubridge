/// Local account lifecycle for guardian/student self-PIN activation.
enum AccountStatus {
  pendingActivation,
  active;

  String get storageValue {
    switch (this) {
      case AccountStatus.pendingActivation:
        return 'pendingActivation';
      case AccountStatus.active:
        return 'active';
    }
  }

  static AccountStatus fromStorage(String? raw) {
    if (raw == AccountStatus.pendingActivation.storageValue) {
      return AccountStatus.pendingActivation;
    }
    return AccountStatus.active;
  }
}
