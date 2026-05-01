/// Claves de persistencia local. No renombrar valores en producción sin migración.
abstract final class JoshPersistenceKeys {
  static const String learningLevel = 'josh_learning_level';
  static const String securityEventLog = 'josh_forensic_log';
  static const int maxSecurityEventEntries = 48;
}
