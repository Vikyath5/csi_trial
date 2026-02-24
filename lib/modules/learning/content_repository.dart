/// ============================================================
/// NeuroVision — Learning Content Repository
/// ============================================================
/// Provides progressive, ADHD-friendly learning content from
/// BASIC (alphabets, numbers) to ADVANCED (science, math).
///
/// Difficulty Levels:
///   1. Basic     — Alphabets (A-Z), Numbers (0-9)
///   2. Beginner  — Numbers (10-100), Simple words, Colors
///   3. Intermediate — Science, Body, Space
///   4. Advanced  — Complex topics, Math concepts
///
/// Each topic includes quiz questions for testing.
/// ============================================================

/// Difficulty level for progressive learning
enum DifficultyLevel { basic, beginner, intermediate, advanced }

/// A quiz question for testing after learning
class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex; // 0-based index of correct answer

  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });
}

class LearningTopic {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final DifficultyLevel difficulty;
  final List<String> lessons;
  final List<QuizQuestion> quiz;

  const LearningTopic({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.difficulty,
    required this.lessons,
    this.quiz = const [],
  });

  String get difficultyLabel {
    switch (difficulty) {
      case DifficultyLevel.basic:
        return 'BASIC';
      case DifficultyLevel.beginner:
        return 'BEGINNER';
      case DifficultyLevel.intermediate:
        return 'INTERMEDIATE';
      case DifficultyLevel.advanced:
        return 'ADVANCED';
    }
  }
}

/// All available learning topics organized by difficulty
class ContentRepository {
  /// Get topics filtered by difficulty level
  static List<LearningTopic> getTopicsByDifficulty(DifficultyLevel level) {
    return topics.where((t) => t.difficulty == level).toList();
  }

  /// Get all difficulty levels with their topic counts
  static Map<DifficultyLevel, int> getDifficultyCounts() {
    final counts = <DifficultyLevel, int>{};
    for (final level in DifficultyLevel.values) {
      counts[level] = topics.where((t) => t.difficulty == level).length;
    }
    return counts;
  }

  static const List<LearningTopic> topics = [
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // BASIC LEVEL — Alphabets & Numbers (for kids/ADHD)
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // ── Alphabets A to M ──
    LearningTopic(
      id: 'alphabets_1',
      title: 'Alphabets A to M',
      description: 'Learn your first 13 letters!',
      emoji: '🔤',
      difficulty: DifficultyLevel.basic,
      lessons: [
        'A is for Apple. A is the first letter of the alphabet. Apple starts with A. Can you say A? A!',
        'B is for Ball. B comes after A. Ball starts with B. B makes the "buh" sound. B!',
        'C is for Cat. C comes after B. Cat starts with C. C can make a "kuh" sound. C!',
        'D is for Dog. D comes after C. Dog starts with D. D makes the "duh" sound. D!',
        'E is for Elephant. E comes after D. Elephant starts with E. E makes the "eh" sound. E!',
        'F is for Fish. F comes after E. Fish starts with F. F makes the "fff" sound. F!',
        'G is for Grapes. G comes after F. Grapes starts with G. G makes the "guh" sound. G!',
        'H is for Hat. H comes after G. Hat starts with H. H makes the "huh" sound. H!',
        'I is for Ice cream. I comes after H. Ice cream starts with I. I makes the "ih" sound. I!',
        'J is for Jug. J comes after I. Jug starts with J. J makes the "juh" sound. J!',
        'K is for Kite. K comes after J. Kite starts with K. K makes the "kuh" sound. K!',
        'L is for Lion. L comes after K. Lion starts with L. L makes the "lll" sound. L!',
        'M is for Mango. M comes after L. Mango starts with M. M makes the "mmm" sound. M!',
      ],
      quiz: [
        QuizQuestion(
          question: 'What letter does "Apple" start with?',
          options: ['A', 'B', 'C', 'D'],
          correctIndex: 0,
        ),
        QuizQuestion(
          question: 'Which letter comes after D?',
          options: ['C', 'F', 'E', 'G'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'What letter does "Cat" start with?',
          options: ['K', 'C', 'S', 'T'],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: 'Which letter does "Hat" start with?',
          options: ['A', 'G', 'H', 'J'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'What comes after L?',
          options: ['K', 'N', 'M', 'O'],
          correctIndex: 2,
        ),
      ],
    ),

    // ── Alphabets N to Z ──
    LearningTopic(
      id: 'alphabets_2',
      title: 'Alphabets N to Z',
      description: 'Learn the rest of the alphabet!',
      emoji: '🔡',
      difficulty: DifficultyLevel.basic,
      lessons: [
        'N is for Nest. N comes after M. Nest starts with N. N makes the "nnn" sound. N!',
        'O is for Orange. O comes after N. Orange starts with O. O makes the "oh" sound. O!',
        'P is for Parrot. P comes after O. Parrot starts with P. P makes the "puh" sound. P!',
        'Q is for Queen. Q comes after P. Queen starts with Q. Q makes the "kwuh" sound. Q!',
        'R is for Rainbow. R comes after Q. Rainbow starts with R. R makes the "rrr" sound. R!',
        'S is for Sun. S comes after R. Sun starts with S. S makes the "sss" sound. S!',
        'T is for Tree. T comes after S. Tree starts with T. T makes the "tuh" sound. T!',
        'U is for Umbrella. U comes after T. Umbrella starts with U. U makes the "uh" sound. U!',
        'V is for Van. V comes after U. Van starts with V. V makes the "vvv" sound. V!',
        'W is for Water. W comes after V. Water starts with W. W makes the "wuh" sound. W!',
        'X is for Xylophone. X comes after W. Xylophone starts with X. X makes the "ks" sound. X!',
        'Y is for Yellow. Y comes after X. Yellow starts with Y. Y makes the "yuh" sound. Y!',
        'Z is for Zebra. Z is the last letter! Zebra starts with Z. Z makes the "zzz" sound. Z!',
      ],
      quiz: [
        QuizQuestion(
          question: 'What letter does "Sun" start with?',
          options: ['C', 'S', 'Z', 'X'],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: 'Which is the last letter of the alphabet?',
          options: ['X', 'Y', 'Z', 'W'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'What letter does "Rainbow" start with?',
          options: ['R', 'B', 'W', 'N'],
          correctIndex: 0,
        ),
        QuizQuestion(
          question: 'Which letter does "Umbrella" start with?',
          options: ['U', 'A', 'O', 'E'],
          correctIndex: 0,
        ),
        QuizQuestion(
          question: 'What comes after T?',
          options: ['S', 'V', 'U', 'W'],
          correctIndex: 2,
        ),
      ],
    ),

    // ── Numbers 0 to 9 ──
    LearningTopic(
      id: 'numbers_basic',
      title: 'Numbers 0 to 9',
      description: 'Learn to count from zero to nine!',
      emoji: '🔢',
      difficulty: DifficultyLevel.basic,
      lessons: [
        'This is the number 0. Zero means nothing or empty. If you have zero apples, your basket is empty!',
        'This is the number 1. One means a single thing. You have 1 nose on your face. One!',
        'This is the number 2. Two means a pair. You have 2 eyes and 2 ears. Two!',
        'This is the number 3. Three comes after two. A triangle has 3 sides. Three!',
        'This is the number 4. Four comes after three. A square has 4 sides. A car has 4 wheels. Four!',
        'This is the number 5. Five is half of ten. You have 5 fingers on each hand. Five!',
        'This is the number 6. Six comes after five. A cube has 6 faces. Six!',
        'This is the number 7. Seven comes after six. There are 7 days in a week. Seven!',
        'This is the number 8. Eight comes after seven. An octopus has 8 arms. Eight!',
        'This is the number 9. Nine comes after eight. Nine is the biggest single digit number. Nine!',
      ],
      quiz: [
        QuizQuestion(
          question: 'How many sides does a triangle have?',
          options: ['2', '3', '4', '5'],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: 'How many fingers do you have on one hand?',
          options: ['4', '3', '5', '6'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'How many days are in a week?',
          options: ['5', '6', '7', '8'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'What number means empty or nothing?',
          options: ['1', '0', '2', '9'],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: 'How many arms does an octopus have?',
          options: ['6', '7', '8', '10'],
          correctIndex: 2,
        ),
      ],
    ),

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // BEGINNER LEVEL — Numbers 10-100, Colors, Shapes
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    // ── Numbers 10 to 50 ──
    LearningTopic(
      id: 'numbers_10_50',
      title: 'Numbers 10 to 50',
      description: 'Counting bigger numbers step by step!',
      emoji: '🔟',
      difficulty: DifficultyLevel.beginner,
      lessons: [
        'The number 10 is made of 1 ten and 0 ones. We call it Ten! You have 10 fingers in total — count them!',
        'The number 20 is made of 2 tens. 10 plus 10 equals 20. We call it Twenty!',
        'The number 25 is made of 2 tens and 5 ones. It is right in the middle between 20 and 30. We call it Twenty-five!',
        'The number 30 is made of 3 tens. 10 plus 10 plus 10 equals 30. We call it Thirty!',
        'The number 40 is made of 4 tens. We call it Forty! Some months have about 30 days.',
        'The number 50 is made of 5 tens. It is half of 100! We call it Fifty!',
      ],
      quiz: [
        QuizQuestion(
          question: 'How many fingers do you have in total?',
          options: ['5', '8', '10', '12'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'What is 10 + 10?',
          options: ['15', '20', '25', '30'],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: '50 is half of what number?',
          options: ['25', '75', '100', '200'],
          correctIndex: 2,
        ),
      ],
    ),

    // ── Numbers 50 to 100 ──
    LearningTopic(
      id: 'numbers_50_100',
      title: 'Numbers 50 to 100',
      description: 'All the way to one hundred!',
      emoji: '💯',
      difficulty: DifficultyLevel.beginner,
      lessons: [
        'The number 60 is made of 6 tens. There are 60 minutes in one hour. Sixty!',
        'The number 70 is made of 7 tens. We call it Seventy!',
        'The number 80 is made of 8 tens. We call it Eighty!',
        'The number 90 is made of 9 tens. It is almost one hundred! Ninety!',
        'The number 100 is made of 10 tens. It is called One Hundred! It is the first three-digit number. 100 pennies make one dollar!',
        'Great job! You now know all the numbers from 0 to 100. You can count to one hundred!',
      ],
      quiz: [
        QuizQuestion(
          question: 'How many minutes are in one hour?',
          options: ['30', '50', '60', '100'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'What number is made of 9 tens?',
          options: ['80', '90', '100', '70'],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: '100 is made of how many tens?',
          options: ['5', '8', '10', '12'],
          correctIndex: 2,
        ),
      ],
    ),

    // ── Colors ──
    LearningTopic(
      id: 'colors',
      title: 'Learn Colors',
      description: 'Red, blue, green and more!',
      emoji: '🌈',
      difficulty: DifficultyLevel.beginner,
      lessons: [
        'Red is the color of an apple, a fire truck, and a tomato. Red is a warm, bright color! Can you find something red near you?',
        'Blue is the color of the sky and the ocean. Blue is a cool, calm color. Your jeans might be blue!',
        'Green is the color of grass, leaves, and frogs. Green means nature and growth!',
        'Yellow is the color of the sun, bananas, and sunflowers. Yellow is a happy, bright color!',
        'Orange is the color of oranges, pumpkins, and carrots. Orange is a warm color between red and yellow!',
        'Purple is the color of grapes and lavender flowers. Purple is made by mixing red and blue together!',
        'Black is the color of night, coal, and shadows. White is the color of snow, clouds, and milk. They are opposites!',
        'Pink is a light red color. You can see pink in roses and flamingos. Brown is the color of chocolate and tree bark!',
      ],
      quiz: [
        QuizQuestion(
          question: 'What color is the sky?',
          options: ['Red', 'Green', 'Blue', 'Yellow'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'What color are bananas?',
          options: ['Orange', 'Yellow', 'Green', 'Red'],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: 'What two colors make purple?',
          options: ['Red + Blue', 'Red + Yellow', 'Blue + Green', 'Yellow + Blue'],
          correctIndex: 0,
        ),
        QuizQuestion(
          question: 'What color are leaves?',
          options: ['Blue', 'Red', 'Yellow', 'Green'],
          correctIndex: 3,
        ),
      ],
    ),

    // ── Shapes ──
    LearningTopic(
      id: 'shapes',
      title: 'Learn Shapes',
      description: 'Circle, triangle, square and more!',
      emoji: '🔷',
      difficulty: DifficultyLevel.beginner,
      lessons: [
        'A circle is round like a ball or a coin. It has no corners and no straight sides. The sun looks like a circle!',
        'A square has 4 equal sides and 4 corners. A window or a chessboard is shaped like a square!',
        'A triangle has 3 sides and 3 corners. A slice of pizza often looks like a triangle!',
        'A rectangle has 4 sides and 4 corners. Two sides are longer than the other two. A door is shaped like a rectangle!',
        'A star has pointed tips sticking out. Stars in the sky twinkle! A star shape usually has 5 points.',
        'A heart shape has two bumps at the top and a point at the bottom. We use hearts to show love!',
      ],
      quiz: [
        QuizQuestion(
          question: 'How many sides does a square have?',
          options: ['3', '4', '5', '6'],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: 'Which shape is round with no corners?',
          options: ['Square', 'Triangle', 'Circle', 'Rectangle'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'How many points does a star usually have?',
          options: ['3', '4', '5', '6'],
          correctIndex: 2,
        ),
      ],
    ),

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // INTERMEDIATE LEVEL — Science Topics
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    LearningTopic(
      id: 'brain',
      title: 'The Human Brain',
      description: 'How your brain works and why it matters',
      emoji: '🧠',
      difficulty: DifficultyLevel.intermediate,
      lessons: [
        'Your brain weighs only about 1.4 kilograms, but it controls everything you do — thinking, feeling, moving, and even breathing while you sleep.',
        'The brain has about 86 billion neurons. Each neuron connects to thousands of others, creating a massive communication network.',
        'The brain is divided into two halves called hemispheres. The left side handles logic and language. The right side handles creativity and spatial awareness.',
        'The frontal lobe sits behind your forehead. It helps you make decisions, solve problems, and control your behavior.',
        'The temporal lobe is near your ears. It processes sounds and helps you understand speech and store memories.',
        'The cerebellum is at the back of your brain. Even though it is small, it coordinates all your movements and helps you keep your balance.',
        'Your brain uses about 20 percent of your body\'s total energy, even though it is only 2 percent of your body weight.',
        'Sleep is critical for your brain. During sleep, your brain cleans out waste products and strengthens important memories from the day.',
      ],
      quiz: [
        QuizQuestion(
          question: 'How much does the brain weigh?',
          options: ['0.5 kg', '1.4 kg', '3 kg', '5 kg'],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: 'Which part controls decisions?',
          options: ['Cerebellum', 'Temporal lobe', 'Frontal lobe', 'Brain stem'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'How much energy does the brain use?',
          options: ['5%', '10%', '15%', '20%'],
          correctIndex: 3,
        ),
      ],
    ),

    LearningTopic(
      id: 'solar_system',
      title: 'Our Solar System',
      description: 'Planets, stars, and space exploration',
      emoji: '🌍',
      difficulty: DifficultyLevel.intermediate,
      lessons: [
        'Our solar system has eight planets orbiting the Sun. The four inner planets — Mercury, Venus, Earth, and Mars — are small and rocky.',
        'The four outer planets — Jupiter, Saturn, Uranus, and Neptune — are much larger and made mostly of gas and ice.',
        'Jupiter is the biggest planet. It is so large that more than 1,300 Earths could fit inside it.',
        'Saturn is famous for its beautiful rings. These rings are made of billions of pieces of ice and rock, some as small as grains of sand.',
        'Earth is the only planet known to support life. It has liquid water, a breathable atmosphere, and a protective magnetic field.',
        'Mars is called the Red Planet because iron oxide (rust) on its surface gives it a reddish color.',
        'The Sun is a star at the center of our solar system. It contains 99.8 percent of all the mass in the solar system.',
        'Light from the Sun takes about 8 minutes to reach Earth, traveling at 300,000 kilometers per second.',
      ],
      quiz: [
        QuizQuestion(
          question: 'How many planets are in our solar system?',
          options: ['6', '7', '8', '9'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'Which is the biggest planet?',
          options: ['Saturn', 'Jupiter', 'Neptune', 'Earth'],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: 'Which planet has beautiful rings?',
          options: ['Mars', 'Jupiter', 'Saturn', 'Neptune'],
          correctIndex: 2,
        ),
      ],
    ),

    LearningTopic(
      id: 'photosynthesis',
      title: 'How Plants Make Food',
      description: 'Photosynthesis explained simply',
      emoji: '🌱',
      difficulty: DifficultyLevel.intermediate,
      lessons: [
        'Plants make their own food through a process called photosynthesis. They use sunlight, water, and carbon dioxide to create sugar and oxygen.',
        'Leaves are the main place where photosynthesis happens. They contain a green pigment called chlorophyll that captures sunlight energy.',
        'Chlorophyll is why most leaves are green. It absorbs red and blue light from the sun and reflects green light back to our eyes.',
        'Water travels up from the roots through tiny tubes in the stem. Carbon dioxide enters the leaf through small pores called stomata.',
        'Inside the leaf, light energy splits water molecules. The hydrogen combines with carbon dioxide to make glucose — the plant\'s food.',
        'Oxygen is released as a waste product of photosynthesis. This is the oxygen that we breathe.',
        'Plants use glucose for energy and growth. Extra glucose is stored as starch in roots, stems, and fruits.',
        'Without photosynthesis, there would be no food chains and very little oxygen. Nearly all life on Earth depends on this process.',
      ],
      quiz: [
        QuizQuestion(
          question: 'What do plants need for photosynthesis?',
          options: ['Sunlight, water, CO2', 'Only water', 'Only sunlight', 'Soil only'],
          correctIndex: 0,
        ),
        QuizQuestion(
          question: 'Why are leaves green?',
          options: ['Because of water', 'Because of chlorophyll', 'Because of oxygen', 'Because of sunlight'],
          correctIndex: 1,
        ),
      ],
    ),

    LearningTopic(
      id: 'water_cycle',
      title: 'The Water Cycle',
      description: 'How water moves around our planet',
      emoji: '💧',
      difficulty: DifficultyLevel.intermediate,
      lessons: [
        'The water cycle describes how water moves continuously between Earth\'s surface and the atmosphere.',
        'Evaporation is when the Sun heats water in oceans, lakes, and rivers, turning it from liquid into water vapor.',
        'As water vapor rises, it cools down and condenses into tiny water droplets. These droplets group together to form clouds.',
        'When clouds collect enough water droplets, the water falls back to Earth as precipitation — rain, snow, sleet, or hail.',
        'Some rainwater flows over the ground into streams and rivers, eventually reaching the ocean. This is called surface runoff.',
        'Some water soaks into the ground and becomes groundwater. Plants absorb this water through their roots.',
        'About 97 percent of Earth\'s water is salty ocean water. Only 3 percent is freshwater.',
        'The water cycle is powered entirely by the Sun\'s energy.',
      ],
      quiz: [
        QuizQuestion(
          question: 'What powers the water cycle?',
          options: ['Wind', 'Moon', 'Sun', 'Earth'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'What percentage of Earth\'s water is salty?',
          options: ['50%', '75%', '90%', '97%'],
          correctIndex: 3,
        ),
      ],
    ),

    LearningTopic(
      id: 'body_systems',
      title: 'Your Body Systems',
      description: 'How your organs work together',
      emoji: '❤️',
      difficulty: DifficultyLevel.intermediate,
      lessons: [
        'Your heart pumps blood through your entire body. It beats about 100,000 times every day.',
        'Blood carries oxygen from your lungs to every cell in your body. It also carries nutrients and removes waste.',
        'Your lungs take in oxygen when you breathe in and release carbon dioxide when you breathe out.',
        'The digestive system breaks down food into nutrients. The process starts in your mouth.',
        'Your stomach uses strong acids to break down food. The small intestine absorbs nutrients.',
        'Your skeleton has 206 bones that protect your organs and help you move.',
        'The nervous system is your body\'s communication network. Messages travel at up to 120 meters per second.',
        'Your immune system protects you from germs. White blood cells find and destroy harmful invaders.',
      ],
      quiz: [
        QuizQuestion(
          question: 'How many times does your heart beat per day?',
          options: ['10,000', '50,000', '100,000', '1,000,000'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'How many bones does an adult have?',
          options: ['106', '206', '306', '406'],
          correctIndex: 1,
        ),
      ],
    ),

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // ADVANCED LEVEL — Math & Complex Topics
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    LearningTopic(
      id: 'math_basics',
      title: 'Math Made Simple',
      description: 'Core math concepts explained clearly',
      emoji: '➕',
      difficulty: DifficultyLevel.advanced,
      lessons: [
        'Fractions represent parts of a whole. When you cut a pizza into 4 equal slices and eat 1 slice, you have eaten one-fourth of the pizza.',
        'A fraction has two parts: the numerator on top and the denominator on bottom. The numerator tells how many parts you have.',
        'Percentages are another way to show parts of a whole, based on 100. Fifty percent means 50 out of 100.',
        'To find 10 percent of any number, simply divide it by 10. For example, 10 percent of 80 is 8.',
        'Ratios compare two quantities. If a class has 12 boys and 8 girls, the ratio is 12 to 8, which simplifies to 3 to 2.',
        'The order of operations: Parentheses, Exponents, Multiplication and Division, then Addition and Subtraction (PEMDAS).',
        'Negative numbers are numbers less than zero. Minus 5 degrees means 5 degrees below zero.',
        'A triangle always has three sides and its angles always add up to exactly 180 degrees.',
      ],
      quiz: [
        QuizQuestion(
          question: 'What is 10% of 80?',
          options: ['4', '8', '12', '16'],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: 'What is the order of operations?',
          options: ['PEMDAS', 'ABCDE', 'BODMAS', 'SADME'],
          correctIndex: 0,
        ),
        QuizQuestion(
          question: 'What do the angles of a triangle add up to?',
          options: ['90°', '120°', '180°', '360°'],
          correctIndex: 2,
        ),
      ],
    ),

    LearningTopic(
      id: 'multiplication',
      title: 'Multiplication Tables',
      description: 'Master your times tables!',
      emoji: '✖️',
      difficulty: DifficultyLevel.advanced,
      lessons: [
        'Multiplication means adding a number to itself many times. 3 times 4 means adding 3 four times: 3 + 3 + 3 + 3 = 12.',
        'The 2 times table: 2, 4, 6, 8, 10, 12, 14, 16, 18, 20. Every answer is an even number!',
        'The 5 times table: 5, 10, 15, 20, 25, 30, 35, 40, 45, 50. Every answer ends in 0 or 5!',
        'The 10 times table is easy: just add a zero! 10, 20, 30, 40, 50, 60, 70, 80, 90, 100.',
        'The 3 times table: 3, 6, 9, 12, 15, 18, 21, 24, 27, 30. Add the digits of each answer — they always add up to 3, 6, or 9!',
        'The 9 times table has a cool trick! In every answer, the digits add up to 9. For example: 9 x 3 = 27, and 2 + 7 = 9!',
        'When you multiply any number by 1, the answer is the same number. 7 times 1 equals 7. This is called the identity property.',
        'When you multiply any number by 0, the answer is always 0. 5 times 0 equals 0. Nothing times anything is nothing!',
      ],
      quiz: [
        QuizQuestion(
          question: 'What is 3 × 4?',
          options: ['7', '10', '12', '15'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'What is 9 × 3?',
          options: ['18', '24', '27', '30'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'Any number times 0 equals?',
          options: ['The number', '1', '0', '10'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'What is 5 × 7?',
          options: ['30', '35', '40', '45'],
          correctIndex: 1,
        ),
      ],
    ),

    LearningTopic(
      id: 'reading_comprehension',
      title: 'Reading Skills',
      description: 'Improve your reading and understanding',
      emoji: '📖',
      difficulty: DifficultyLevel.advanced,
      lessons: [
        'When you read a story, try to find the main idea. The main idea is what the story is mostly about.',
        'Characters are the people or animals in a story. Pay attention to what characters do and say.',
        'The setting is where and when a story takes place. Is it in a city? A forest? Is it daytime or nighttime?',
        'Every story has a beginning, a middle, and an end. The beginning introduces the characters. The middle has the problem. The end has the solution.',
        'When you read, stop and ask yourself questions. Did I understand what I just read? Can I explain it in my own words?',
        'Context clues are words around an unknown word that help you figure out its meaning. Look at the sentence around it.',
        'Prediction means guessing what will happen next in a story. Good readers make predictions based on clues in the text.',
        'A summary is a short version of what you read. It includes only the most important parts.',
      ],
      quiz: [
        QuizQuestion(
          question: 'What is the main idea of a story?',
          options: ['The title', 'What the story is mostly about', 'The first sentence', 'The last word'],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: 'What is the setting of a story?',
          options: ['The characters', 'The problem', 'Where and when it takes place', 'The ending'],
          correctIndex: 2,
        ),
        QuizQuestion(
          question: 'What are context clues?',
          options: ['Pictures in a book', 'Words that help figure out unknown words', 'Page numbers', 'Chapter titles'],
          correctIndex: 1,
        ),
      ],
    ),
  ];

  /// Returns a topic by its ID
  static LearningTopic? getTopicById(String id) {
    try {
      return topics.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}
