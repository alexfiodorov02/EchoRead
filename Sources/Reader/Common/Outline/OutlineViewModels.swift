//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import SwiftUI

// This file contains view model wrappers for fetching data from Repositories: Bookmarks and Highlights.
// It's not acceptable to fetch that data in a Swiftui View's constructor, so we need a reactive wrapper.

// MARK: - Highlights

final class HighlightsViewModel: ObservableObject {
    func deleteHighlights(at offsets: IndexSet) {
        let idsToDelete = offsets.map { highlights[$0].id }
        highlights.remove(atOffsets: offsets)

        Task {
            for id in idsToDelete {
                if let id = id {
                    try? await repository.remove(id)
                }
            }
        }
    }
    typealias T = Highlight
    @Published var highlights = [Highlight]()

    private let bookId: Book.Id
    private let repository: HighlightRepository

    private lazy var loader: OutlineViewModelLoader<Highlight> = OutlineViewModelLoader(
        dataTask: { [repository, bookId] in repository.all(for: bookId) },
        setLoadedValues: { [weak self] values in self?.highlights = values }
    )

    init(bookId: Book.Id, repository: HighlightRepository) {
        self.bookId = bookId
        self.repository = repository
    }

    func load() {
        loader.load()
    }

    func loadIfNeeded() {
        loader.loadIfNeeded()
    }

    var dataTask: AnyPublisher<[Highlight], Error> {
        repository.all(for: bookId)
    }

    func setLoadedValues(_ values: [Highlight]) {
        highlights = values
    }
}

// MARK: - Bookmarks

final class BookmarksViewModel: ObservableObject {
    typealias T = Bookmark
    @Published var bookmarks = [Bookmark]()

    private let bookId: Book.Id
    private let repository: BookmarkRepository

    private lazy var loader: OutlineViewModelLoader<Bookmark> = OutlineViewModelLoader(
        dataTask: { [repository, bookId] in repository.all(for: bookId) },
        setLoadedValues: { [weak self] values in self?.bookmarks = values }
    )

    init(bookId: Book.Id, repository: BookmarkRepository) {
        self.bookId = bookId
        self.repository = repository
    }

    func load() {
        loader.load()
    }

    func loadIfNeeded() {
        loader.loadIfNeeded()
    }

    var dataTask: AnyPublisher<[Bookmark], Error> {
        repository.all(for: bookId)
    }

    func setLoadedValues(_ values: [Bookmark]) {
        bookmarks = values
    }

    func deleteBookmarks(at offsets: IndexSet) {
        let idsToDelete = offsets.map { bookmarks[$0].id }
        bookmarks.remove(atOffsets: offsets)

        Task {
            for id in idsToDelete {
                if let id = id {
                    try? await repository.remove(id)
                }
            }
        }
    }
}

// MARK: - Generic state management


// This loader contains a state enum which can be used for expressive UI (loading progress, error handling etc). For this, status overlay view can be used (see https://stackoverflow.com/a/61858358/2567725).
private final class OutlineViewModelLoader<T> {
    private var state = State.ready

    enum State {
        case ready
        case loading(Combine.Cancellable)
        case loaded
        case error(Error)
    }

    private let dataTask: () -> AnyPublisher<[T], Error>
    private let setLoadedValues: ([T]) -> Void

    init(dataTask: @escaping () -> AnyPublisher<[T], Error>, setLoadedValues: @escaping ([T]) -> Void) {
        self.dataTask = dataTask
        self.setLoadedValues = setLoadedValues
    }

    func load() {
        assert(Thread.isMainThread)
        state = .loading(dataTask().sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case let .failure(error):
                    self.state = .error(error)
                }
            },
            receiveValue: { value in
                self.state = .loaded
                self.setLoadedValues(value)
            }
        ))
    }

    func loadIfNeeded() {
        assert(Thread.isMainThread)
        guard case .ready = state else { return }
        load()
    }
}
