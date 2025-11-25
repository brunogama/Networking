import Foundation
import Networking

// Entry point for the sample app
// Using async main pattern

// Create a client with HTTPie middleware for request/response logging
let httpieMiddleware = HTTPieMiddleware(
  configuration: HTTPieMiddleware.Configuration(
    printRequest: true,
    printResponse: true,
    printHeaders: false,
    printBody: true,
    maxBodyLength: 512,
    colorized: true
  )
)

let loggingClient = NetworkClient(
  requestMiddlewares: [httpieMiddleware],
  responseMiddlewares: [httpieMiddleware]
)

// Manual implementations (using RequestBuilder DSL directly)
let githubManual = GitHubClient()
let jsonPlaceholderManual = JSONPlaceholderClient()

// Macro-generated implementations (using @API protocol macro)
// Pass the logging client to see HTTPie-style output
let github = GitHubAPIImplementation(client: loggingClient)
let jsonPlaceholder = JSONPlaceholderAPIImplementation(client: loggingClient)

print("ModernNetworking Sample App")
print("===========================")
print("Using @API macro-generated implementations with HTTPie logging\n")

await runDemos()

func runDemos() async {
  do {
    // Demo 1: GitHub User Lookup
    print("1. GitHub User Lookup")
    print(String(repeating: "-", count: 40))
    let user = try await github.getUser(username: "apple")
    print("   User: \(user.login)")
    print("   Name: \(user.name ?? "N/A")")
    print("   Public Repos: \(user.publicRepos ?? 0)")
    print("   Followers: \(user.followers ?? 0)")
    print()

    // Demo 2: Repository Search
    print("2. Repository Search")
    print(String(repeating: "-", count: 40))
    let searchResults = try await github.searchRepositories(
      searchQuery: "swift language:swift",
      perPage: 3,
      page: 1
    )
    print("   Total results: \(searchResults.totalCount)")
    print("   Top 3 repositories:")
    for repo in searchResults.items.prefix(3) {
      print("     - \(repo.fullName) (\(repo.stargazersCount) stars)")
    }
    print()

    // Demo 3: Get Specific Repository
    print("3. Get Repository")
    print(String(repeating: "-", count: 40))
    let swiftRepo = try await github.getRepository(owner: "apple", repo: "swift")
    print("   Name: \(swiftRepo.fullName)")
    print("   Description: \(swiftRepo.description ?? "N/A")")
    print("   Stars: \(swiftRepo.stargazersCount)")
    print("   Forks: \(swiftRepo.forksCount)")
    print()

    // Demo 4: JSONPlaceholder Posts
    print("4. JSONPlaceholder Posts")
    print(String(repeating: "-", count: 40))
    let posts = try await jsonPlaceholder.getPosts()
    print("   Total posts: \(posts.count)")
    print("   First post title: \(posts.first?.title ?? "N/A")")
    print()

    // Demo 5: Get Single Post
    print("5. Get Single Post")
    print(String(repeating: "-", count: 40))
    let post = try await jsonPlaceholder.getPost(id: 1)
    print("   Post ID: \(post.id ?? 0)")
    print("   Title: \(post.title)")
    print()

    // Demo 6: Create Post
    print("6. Create Post")
    print(String(repeating: "-", count: 40))
    let newPost = Post(
      id: nil,
      userId: 1,
      title: "Test Post from ModernNetworking",
      body: "This post was created using the RequestBuilder DSL!"
    )
    let createdPost = try await jsonPlaceholder.createPost(post: newPost)
    print("   Created post ID: \(createdPost.id ?? 0)")
    print("   Title: \(createdPost.title)")
    print()

    print("All demos completed successfully!")
  } catch {
    print("Error: \(error)")
  }
}
