enum InterpreterShift { morning, night, emergency }

extension InterpreterShiftX on InterpreterShift {
  String get label {
    switch (this) {
      case InterpreterShift.morning:
        return 'Morning Shift';
      case InterpreterShift.night:
        return 'Night Shift';
      case InterpreterShift.emergency:
        return 'Emergency On-Call';
    }
  }

  String get description {
    switch (this) {
      case InterpreterShift.morning:
        return 'Available between 6:00 AM and 2:00 PM (local time).';
      case InterpreterShift.night:
        return 'Available between 6:00 PM and 2:00 AM (local time).';
      case InterpreterShift.emergency:
        return 'Can respond to urgent medical calls with a 30% rate uplift.';
    }
  }
}
