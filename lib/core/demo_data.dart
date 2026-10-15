import '../models/content.dart';

/// Bundled sample content for the Roadmaps, Resources and Collabs screens.
///
/// Shown whenever the backend has nothing to return yet (fresh account,
/// empty collections, or an endpoint gated behind reputation) so the screens
/// stay presentable while demoing. Every id is prefixed `demo-`: list screens
/// use that to raise a "sample content" banner and detail screens resolve
/// demo items locally instead of hitting the API.

final List<Roadmap> demoRoadmaps = [
  Roadmap(
    id: 'demo-roadmap-blind75',
    title: 'Blind 75 in 8 weeks',
    goal: 'Work through the classic interview set at a sustainable pace.',
    level: 'Intermediate',
    createdAt: DateTime(2026, 9, 1),
    phases: [
      RoadmapPhase(
        title: 'Weeks 1–2 · Arrays & hashing',
        description: 'Build fluency with the map/set toolkit before touching harder patterns.',
        items: [
          'Two Sum · Best Time to Buy and Sell Stock',
          'Contains Duplicate · Product of Array Except Self',
          'Longest Consecutive Sequence · Group Anagrams',
          'Encode and Decode Strings (design warm-up)',
        ],
      ),
      RoadmapPhase(
        title: 'Weeks 3–4 · Two pointers & sliding window',
        description: 'The pattern behind most "substring/subarray" questions.',
        items: [
          'Valid Palindrome · 3Sum · Container With Most Water',
          'Longest Substring Without Repeating Characters',
          'Minimum Window Substring · Sliding Window Maximum',
        ],
      ),
      RoadmapPhase(
        title: 'Weeks 5–6 · Trees, graphs & heaps',
        description: 'Traversal fluency: BFS, DFS, and when a heap beats a sort.',
        items: [
          'Invert Binary Tree · Validate BST · Lowest Common Ancestor',
          'Number of Islands · Clone Graph · Course Schedule',
          'Find Median from Data Stream · Kth Largest Element',
        ],
      ),
      RoadmapPhase(
        title: 'Weeks 7–8 · Dynamic programming & review',
        description: 'Close with the classics, then redo every missed problem from scratch.',
        items: [
          'Climbing Stairs · House Robber · Coin Change',
          'Longest Increasing Subsequence · Unique Paths · Word Break',
          'Timed re-solve of every problem you failed the first time',
        ],
        isDone: false,
      ),
    ],
  ),
  Roadmap(
    id: 'demo-roadmap-sysdesign',
    title: 'System design for beginners',
    goal: 'Go from "no idea where to start" to a repeatable interview framework.',
    level: 'Beginner',
    createdAt: DateTime(2026, 9, 12),
    phases: [
      RoadmapPhase(
        title: 'Foundations',
        description: 'Vocabulary you will use in every design conversation.',
        items: [
          'Latency vs throughput · CAP theorem in plain words',
          'Load balancers, caches and CDNs — what problem each solves',
          'SQL vs NoSQL: picking storage on access patterns',
        ],
      ),
      RoadmapPhase(
        title: 'The interview framework',
        description: 'A fixed order of operations so you never freeze at the whiteboard.',
        items: [
          'Clarify requirements and draw the API surface first',
          'Back-of-envelope capacity estimates (QPS, storage, bandwidth)',
          'Sketch the data model, then scale out the hot components',
        ],
        isDone: true,
      ),
      RoadmapPhase(
        title: 'Guided walkthroughs',
        description: 'One classic per sitting; write it up from memory afterwards.',
        items: [
          'URL shortener · rate limiter · key-value store',
          'News feed · chat system · notification service',
        ],
      ),
    ],
  ),
  Roadmap(
    id: 'demo-roadmap-dp',
    title: 'Dynamic programming deep dive',
    goal: 'Turn DP from guesswork into a mechanical recognition drill.',
    level: 'Advanced',
    createdAt: DateTime(2026, 9, 20),
    phases: [
      RoadmapPhase(
        title: '1-D problems',
        description: 'Learn the state/transition/answer ritual on small states.',
        items: [
          'Climbing Stairs · Min Cost Climbing Stairs',
          'House Robber I & II · Delete and Earn',
          'Longest Increasing Subsequence (O(n²), then patience sorting)',
        ],
      ),
      RoadmapPhase(
        title: '2-D grids & knapsacks',
        description: 'Same ritual, one more index of state.',
        items: [
          'Unique Paths I & II · Minimum Path Sum',
          '0/1 Knapsack · Partition Equal Subset Sum · Coin Change',
        ],
      ),
      RoadmapPhase(
        title: 'Strings & intervals',
        description: 'Where the transition lives between characters, not cells.',
        items: [
          'Longest Common Subsequence · Edit Distance',
          'Palindromic Substrings · Burst Balloons · Word Break',
        ],
      ),
    ],
  ),
];

Roadmap demoRoadmapById(String id) =>
    demoRoadmaps.firstWhere((r) => r.id == id, orElse: () => demoRoadmaps.first);

final List<ResourceItem> demoResources = [
  ResourceItem(
    id: 'demo-resource-bigo',
    title: 'The Big-O cheat sheet',
    summary:
        'One table for the complexities you actually get asked about — array, '
        'hash map, heap, and the common sorts — plus the three questions that '
        'let you derive any of them instead of memorising: what does the loop '
        'touch, how often does it run, and what does each step cost?',
    category: 'algorithms',
    author: 'dsa_team',
    votes: 142,
  ),
  ResourceItem(
    id: 'demo-resource-sliding-window',
    title: 'Sliding window — 12 patterns that cover everything',
    summary:
        'Every sliding window problem is one of twelve shapes: fixed vs dynamic '
        'window, longest vs shortest vs count, and the two shrink conditions '
        '(invalid state vs target met). Each pattern comes with a canonical '
        'problem and a template you can retype from memory.',
    category: 'algorithms',
    author: 'priya.dev',
    votes: 98,
  ),
  ResourceItem(
    id: 'demo-resource-graphs',
    title: 'Graph traversal templates (BFS, DFS, topological sort)',
    summary:
        'Copy-paste-ready templates for adjacency-list BFS/DFS, multi-source '
        'BFS, cycle detection, and Kahn\'s topological sort — with comments on '
        'the two lines people usually get wrong: marking visited and handling '
        'disconnected components.',
    category: 'data-structures',
    author: 'marco-codes',
    votes: 76,
  ),
  ResourceItem(
    id: 'demo-resource-complexity',
    title: 'How to estimate time complexity quickly',
    summary:
        'Interview-safe rules of thumb: nested loops multiply, halved work is a '
        'log, recursion cost is (branching^depth) unless states repeat — then '
        'it\'s states × work-per-state. Includes a printable card of the ten '
        'recurrences that cover 90% of divide-and-conquer code.',
    category: 'problem-solving',
    author: 'ada_lo',
    votes: 54,
  ),
  ResourceItem(
    id: 'demo-resource-url-shortener',
    title: 'System design primer: the URL shortener',
    summary:
        'The canonical first design interview, dissected: counter vs hash-based '
        'key generation, read-heavy caching, 301 vs 302 redirects, and the '
        'analytics wrinkle. Ends with the follow-up questions interviewers '
        'actually ask and how to pivot your design for each.',
    category: 'system-design',
    author: 'dsa_team',
    votes: 61,
  ),
  ResourceItem(
    id: 'demo-resource-recursion',
    title: 'Recursion to iteration: one mental model',
    summary:
        'Every recursive function is a stack of frames with three parts — base '
        'case, shrink step, combine step. This guide shows how to translate '
        'each part to an explicit stack, and when the iterative version is '
        'worth it (deep trees, memory limits) versus noise.',
    category: 'problem-solving',
    author: 'null_ptr',
    votes: 39,
  ),
];

ResourceItem demoResourceById(String id) => demoResources
    .firstWhere((r) => r.id == id, orElse: () => demoResources.first);

/// Sample rows for the public review queue ("Queue" tab).
final List<SuggestedEdit> demoReviewQueue = [
  SuggestedEdit(
    id: 'demo-edit-1',
    resourceType: 'resource',
    resourceId: 'demo-resource-sliding-window',
    suggestedByName: 'marco-codes',
    reason:
        'Pattern 7\'s template forgets to shrink the window when the count map '
        'goes negative — added the missing guard and a failing test case.',
    approveVotes: 4,
    rejectVotes: 1,
    createdAt: DateTime(2026, 9, 27, 10, 24),
  ),
  SuggestedEdit(
    id: 'demo-edit-2',
    resourceType: 'resource',
    resourceId: 'demo-resource-bigo',
    suggestedByName: 'ada_lo',
    reason: 'Quicksort is listed as O(n log n) worst case; corrected to O(n²) with the pivot note.',
    approveVotes: 2,
    rejectVotes: 0,
    createdAt: DateTime(2026, 9, 28, 16, 3),
  ),
  SuggestedEdit(
    id: 'demo-edit-3',
    resourceType: 'help-article',
    resourceId: 'how-reputation-works',
    suggestedByName: 'priya.dev',
    reason: 'The +10 reputation figure changed to +5 after the last release; updated both mentions.',
    approveVotes: 5,
    rejectVotes: 0,
    createdAt: DateTime(2026, 9, 29, 9, 41),
  ),
  SuggestedEdit(
    id: 'demo-edit-4',
    resourceType: 'resource',
    resourceId: 'demo-resource-graphs',
    suggestedByName: 'null_ptr',
    reason: 'Added the missing "mark visited on enqueue" line to the BFS template.',
    approveVotes: 1,
    rejectVotes: 2,
    createdAt: DateTime(2026, 9, 26, 19, 12),
  ),
];

/// Sample rows for "My suggestions" — statuses show the review lifecycle.
final List<SuggestedEdit> demoMySuggestions = [
  SuggestedEdit(
    id: 'demo-mine-1',
    resourceType: 'resource',
    resourceId: 'demo-resource-url-shortener',
    suggestedByName: 'you',
    reason: 'Clarified that 301 redirects are cached by browsers, which breaks click analytics.',
    status: 'approved',
    approveVotes: 6,
    rejectVotes: 0,
    createdAt: DateTime(2026, 9, 22, 14, 30),
  ),
  SuggestedEdit(
    id: 'demo-mine-2',
    resourceType: 'resource',
    resourceId: 'demo-resource-complexity',
    suggestedByName: 'you',
    reason: 'Added the T(n) = 2T(n/2) + n recurrence to the printable card.',
    status: 'pending',
    approveVotes: 3,
    rejectVotes: 1,
    createdAt: DateTime(2026, 9, 28, 11, 5),
  ),
  SuggestedEdit(
    id: 'demo-mine-3',
    resourceType: 'resource',
    resourceId: 'demo-resource-recursion',
    suggestedByName: 'you',
    reason: 'Proposed dropping the factorial example for a more realistic tree walk.',
    status: 'rejected',
    approveVotes: 1,
    rejectVotes: 4,
    createdAt: DateTime(2026, 9, 25, 8, 47),
  ),
];
