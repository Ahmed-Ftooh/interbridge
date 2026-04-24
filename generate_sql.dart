import 'dart:io';
import 'dart:convert';

void main() async {
  var file = File('parse_quizzes.py');
  var content = await file.readAsString();
  var text = content.split('text = """')[1].split('"""')[0].trim();

  final Map<String, String> sectionNames = {
    'cardiology': 'CARDIO SYSTEM – 25 Questions',
    'respiratory': 'RESPIRATORY SYSTEM – 25 Questions',
    'gastrointestinal': 'GASTROINTESTINAL SYSTEM – 25 Questions',
    'endocrinology': 'ENDOCRINE SYSTEM',
    'renal': 'RENAL SYSTEM',
    'ob_gyn': 'OB/GYN SYSTEM',
    'oncology': 'Oncology',
    'dermatology': 'Dermatology',
    'emergency': 'EMERGENCY / ER',
    'ear_and_eye': 'Ear and eye'
  };

  var splits = <String, String>{};
  var remaining = text;

  final keys = sectionNames.keys.toList();
  for (int i = 0; i < keys.length; i++) {
    var catId = keys[i];
    var header = sectionNames[catId]!;

    if (i < keys.length - 1) {
      var nextHeader = sectionNames[keys[i + 1]]!;
      var parts = remaining.split(nextHeader);
      splits[catId] = parts[0].replaceAll(header, '').trim();
      remaining = parts.sublist(1).join(nextHeader);
    } else {
      splits[catId] = remaining.replaceAll(header, '').trim();
    }
  }

  var sqlInserts = <String>[];

  splits.forEach((catId, questionsStr) {
    if (questionsStr.isEmpty) return;

    // Split by numbering prefix like '1. ', '12..', etc.
    final regex = RegExp(r'\n\s*\d+\s*(?:\.\s*\d+\.\s*|\.+|\s+)\s*');
    var rawQs = ('\n' + questionsStr).split(regex).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    for (var qBlob in rawQs) {
      var lines = qBlob.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.isEmpty) continue;

      var correctOptionLetter = 'A';

      if (lines.last.toLowerCase().startsWith('answer:')) {
        var ansLine = lines.removeLast();
        var ansVal = ansLine.split(':').last.trim().toUpperCase();
        if (['A', 'B', 'C', 'D'].contains(ansVal)) {
          correctOptionLetter = ansVal;
        }
      }

      var qTextLines = <String>[];
      var optionLines = <String>[];

      if (lines.length >= 5) {
        qTextLines = lines.sublist(0, lines.length - 4);
        optionLines = lines.sublist(lines.length - 4);
      } else if (lines.length > 1) {
        qTextLines = [lines[0]];
        optionLines = lines.sublist(1);
      } else {
        qTextLines = lines;
        optionLines = [];
      }

      var cleanOpts = <String>[];
      var foundCorrectIndex = -1;

      for (var oIdx = 0; oIdx < optionLines.length; oIdx++) {
        var opt = optionLines[oIdx];
        if (opt.contains('✔')) {
          foundCorrectIndex = oIdx;
        }

        var optText = opt.replaceAll('✔', '').trim();
        optText = optText.replaceAll(RegExp(r'^(?:[A-D]|\d+)\s*\.\s*'), '').trim();
        cleanOpts.add(optText);
      }

      if (foundCorrectIndex != -1 && foundCorrectIndex < 4) {
        correctOptionLetter = ['A', 'B', 'C', 'D'][foundCorrectIndex];
      }

      while (cleanOpts.length < 4) {
        cleanOpts.add('None of the above');
      }

      var qt = qTextLines.join(' ').replaceAll("'", "''");
      var oA = cleanOpts[0].replaceAll("'", "''");
      var oB = cleanOpts[1].replaceAll("'", "''");
      var oC = cleanOpts[2].replaceAll("'", "''");
      var oD = cleanOpts[3].replaceAll("'", "''");

      sqlInserts.add("  ('medical', '$catId', '$qt', '$oA', '$oB', '$oC', '$oD', '$correctOptionLetter')");
    }
  });

  var finalSql = '''-- Replace remaining medical quiz banks with updated questions

ALTER TYPE medical_section_type ADD VALUE IF NOT EXISTS 'ear_and_eye';

DELETE FROM public.quiz_questions
WHERE quiz_type = 'medical'
  AND medical_section IN (
    'cardiology', 'respiratory', 'gastrointestinal', 'endocrinology', 
    'renal', 'ob_gyn', 'oncology', 'dermatology', 'emergency', 'ear_and_eye'
  );

INSERT INTO public.quiz_questions(
  quiz_type,
  medical_section,
  question_text,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_option
) VALUES
${sqlInserts.join(',\n')};
''';

  await File('supabase/migrations/20260406000003_replace_remaining_medical_questions.sql').writeAsString(finalSql);
  print('Generated SQL successfully.');
}
