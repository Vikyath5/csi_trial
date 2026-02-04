enum ActiveModule { adhd, tactile }

class ModuleResolver {
  static ActiveModule resolve(String accessibilityMode) {
    if (accessibilityMode == 'tactile') {
      return ActiveModule.tactile;
    }
    return ActiveModule.adhd;
  }
}
