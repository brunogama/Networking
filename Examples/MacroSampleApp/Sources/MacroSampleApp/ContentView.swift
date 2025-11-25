import SwiftUI

struct ContentView: View {
  @State private var viewModel = DogViewModel()

  var body: some View {
    NavigationSplitView {
      sidebar
    } detail: {
      detailView
    }
    .navigationSplitViewStyle(.balanced)
  }

  private var sidebar: some View {
    List(selection: $viewModel.selectedBreed) {
      Section("Dog Breeds") {
        ForEach(viewModel.breeds, id: \.self) { breed in
          NavigationLink(value: breed) {
            Label(breed.capitalized, systemImage: "pawprint.fill")
          }
        }
      }
    }
    .listStyle(.sidebar)
    .navigationTitle("Macro Sample")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button(action: { Task { await viewModel.loadBreeds() } }) {
          Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isLoading)
      }
    }
    .task {
      await viewModel.loadBreeds()
    }
  }

  private var detailView: some View {
    Group {
      if let breed = viewModel.selectedBreed {
        breedDetailView(breed: breed)
      } else {
        placeholderView
      }
    }
  }

  private func breedDetailView(breed: String) -> some View {
    VStack(spacing: 20) {
      Text(breed.capitalized)
        .font(.largeTitle)
        .fontWeight(.bold)

      if viewModel.isLoadingImage {
        ProgressView()
          .scaleEffect(2)
          .frame(width: 400, height: 300)
      } else if let imageURL = viewModel.currentImageURL {
        AsyncImage(url: URL(string: imageURL)) { phase in
          switch phase {
          case .empty:
            ProgressView()
              .frame(width: 400, height: 300)

          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(maxWidth: 500, maxHeight: 400)
              .clipShape(RoundedRectangle(cornerRadius: 12))
              .shadow(radius: 8)

          case .failure:
            Image(systemName: "photo")
              .font(.system(size: 60))
              .foregroundStyle(.secondary)
              .frame(width: 400, height: 300)

          @unknown default:
            EmptyView()
          }
        }
      }

      HStack(spacing: 16) {
        Button("Random Image") {
          Task { await viewModel.loadRandomImage(for: breed) }
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.isLoadingImage)

        if let error = viewModel.error {
          Text(error)
            .foregroundStyle(.red)
            .font(.caption)
        }
      }

      Spacer()

      httpieLogView
    }
    .padding()
    .task(id: breed) {
      await viewModel.loadRandomImage(for: breed)
    }
  }

  private var placeholderView: some View {
    VStack(spacing: 16) {
      Image(systemName: "dog.fill")
        .font(.system(size: 80))
        .foregroundStyle(.secondary)
      Text("Select a breed")
        .font(.title2)
        .foregroundStyle(.secondary)
      Text("Using @API macro-generated client")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
  }

  private var httpieLogView: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("HTTPie Log")
        .font(.headline)
        .foregroundStyle(.secondary)

      ScrollView {
        Text(viewModel.httpieLog)
          .font(.system(.caption, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }
      .frame(height: 120)
      .padding(8)
      .background(Color(nsColor: .textBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .padding(.horizontal)
  }
}

#Preview {
  ContentView()
}
