enum InterpreterLevel { volunteer, paid }

extension InterpreterLevelX on InterpreterLevel {
  String get label {
    switch (this) {
      case InterpreterLevel.volunteer:
        return 'Volunteer';
      case InterpreterLevel.paid:
        return 'Paid Professional';
    }
  }

  String get badge {
    switch (this) {
      case InterpreterLevel.volunteer:
        return 'Volunteer Track';
      case InterpreterLevel.paid:
        return 'Certified Professional';
    }
  }

  bool get requiresMedicalCredentials => this == InterpreterLevel.paid;
}
