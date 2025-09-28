import SwiftUI
import Combine


// MARK: - Models
struct Exercise: Identifiable, Hashable {
    let id = UUID()
    var name: String
}

struct WorkoutSet: Identifiable {
    let id = UUID()
    var exercise: Exercise
    var weight: Double
    var reps: Int
    var completed: Bool = false   // new property
}


struct Workout: Identifiable {
    let id = UUID()
    var name: String
    var date: Date
    var sets: [WorkoutSet]
}

struct WorkoutTemplate: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var sets: [WorkoutSet] = []

    static func == (lhs: WorkoutTemplate, rhs: WorkoutTemplate) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}


struct WorkoutSession: Identifiable, Hashable {
    let id = UUID()
    var template: WorkoutTemplate
    var sets: [WorkoutSet]
    var startTime: Date
    var endTime: Date? = nil

    static func == (lhs: WorkoutSession, rhs: WorkoutSession) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}




// MARK: - ViewModel (in-memory store)
class WorkoutStore: ObservableObject {
    @Published var templates: [WorkoutTemplate] = []
    @Published var sessions: [WorkoutSession] = []
    @Published var exercises: [Exercise] = [
        Exercise(name: "Bench Press"),
        Exercise(name: "Squat"),
        Exercise(name: "Deadlift")
    ]
    
    // MARK: - Templates
    func addTemplate(name: String, sets: [WorkoutSet]) {
        let template = WorkoutTemplate(name: name, sets: sets)
        templates.append(template)
    }
    
    // MARK: - Sessions
    func startSession(from template: WorkoutTemplate) -> WorkoutSession {
        let session = WorkoutSession(
            template: template,
            sets: template.sets,
            startTime: Date()
        )
        sessions.append(session)
        return session
    }
    
    func finishSession(_ session: WorkoutSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        var updatedSession = sessions[index]
        updatedSession.endTime = Date()
        sessions[index] = updatedSession // reassign triggers @Published
    }
    
    func duplicateLastSet(in session: WorkoutSession) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        guard let lastSet = sessions[sessionIndex].sets.last else { return }
        
        let newSet = WorkoutSet(
            exercise: lastSet.exercise,
            weight: lastSet.weight,
            reps: lastSet.reps,
            completed: false
        )
        sessions[sessionIndex].sets.append(newSet)
    }
    
    func addSet(to template: WorkoutTemplate, set: WorkoutSet) {
        guard let index = templates.firstIndex(where: { $0.id == template.id }) else { return }
        templates[index].sets.append(set)
    }
    
    func startSessionAndReturn(from template: WorkoutTemplate) -> WorkoutSession {
        let session = WorkoutSession(template: template, sets: template.sets, startTime: Date())
        sessions.append(session)
        return session
    }
}


// MARK: - Views

struct ContentView: View {
    @StateObject private var store = WorkoutStore()
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                templatesSection
                sessionsSection
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("Add Template") {
                        AddTemplateView()
                            .environmentObject(store)
                    }
                }
            }
            .navigationDestination(for: WorkoutTemplate.self) { template in
                TemplateDetailView(navigationPath: $navigationPath, template: template)
                    .environmentObject(store)
            }
            .navigationDestination(for: WorkoutSession.self) { session in
                WorkoutDetailView(navigationPath: $navigationPath, session: session)
                    .environmentObject(store)
            }
        }
    }
    
    // MARK: - Sections
    
    private var templatesSection: some View {
        Section("Templates") {
            ForEach(store.templates) { template in
                NavigationLink(value: template) {
                    Text(template.name)
                }
            }
        }
    }
    
    private var sessionsSection: some View {
        Section("Sessions") {
            ForEach(store.sessions) { session in
                NavigationLink(value: session) {
                    VStack(alignment: .leading) {
                        Text(session.template.name)
                        if let end = session.endTime {
                            Text("Finished: \(end, style: .time)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else {
                            Text("In Progress")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
    }
}





struct TemplatesView: View {
    @EnvironmentObject var store: WorkoutStore
    @Binding var navigationPath: NavigationPath // <- add this binding

    
    var body: some View {
        NavigationView {
            List {
                ForEach(store.templates) { template in
                    NavigationLink(template.name) {
                        SessionView(template: template, navigationPath: $navigationPath).environmentObject(store)
                    }
                }
            }
            .navigationTitle("Workout Templates")
        }
    }
}

struct AddTemplateView: View {
    @EnvironmentObject var store: WorkoutStore
    @Environment(\.dismiss) var dismiss
    
    @State private var name: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("Template Name")) {
                TextField("Enter workout name", text: $name)
            }
            
            Section {
                Button("Save") {
                    let newTemplate = WorkoutTemplate(name: name, sets: [])
                    store.templates.append(newTemplate)
                    dismiss()
                }
                .disabled(name.isEmpty)
            }
        }
        .navigationTitle("New Template")
    }
}

struct TemplateDetailView: View {
    @EnvironmentObject var store: WorkoutStore
    @Binding var navigationPath: NavigationPath
    var template: WorkoutTemplate  // no local copy

    var body: some View {
        VStack {
            // Fetch the latest template from the store
            let currentTemplate = store.templates.first(where: { $0.id == template.id }) ?? template
            let weight = 0;
            let reps = 0;

            if currentTemplate.sets.isEmpty {
                VStack(spacing: 20) {
                    Text("This template has no exercises yet.")
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    NavigationLink("Add Your First Set") {
                        AddSetView(template: Binding(
                            get: { currentTemplate },
                            set: { newValue in
                                if let index = store.templates.firstIndex(where: { $0.id == template.id }) {
                                    store.templates[index] = newValue
                                }
                            }
                        ))
                        .environmentObject(store)
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
            } else {
                List {
                    ForEach(groupedSets(for: currentTemplate).keys.sorted(by: { $0.name < $1.name }), id: \.self) { exercise in
                        Section(header: Text(exercise.name).font(.headline)) {
                            if let sets = groupedSets(for: currentTemplate)[exercise],
                               let templateIndex = store.templates.firstIndex(where: { $0.id == template.id }) {

                                ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                                    if let setIndex = store.templates[templateIndex].sets.firstIndex(where: { $0.id == set.id }) {
                                        HStack {
                                            Text("Set \(index + 1)")
                                                .frame(width: 60, alignment: .leading)

                                            TextField("Weight",
                                                      value: $store.templates[templateIndex].sets[setIndex].weight,
                                                      formatter: NumberFormatter())
                                                .keyboardType(.decimalPad)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .frame(width: 70)

                                            Text("kg")

                                            TextField("Reps",
                                                      value: $store.templates[templateIndex].sets[setIndex].reps,
                                                      formatter: NumberFormatter())
                                                .keyboardType(.numberPad)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .frame(width: 60)

                                            Text("reps")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                HStack {
                    NavigationLink("Add Set") {
                        AddSetView(template: Binding(
                            get: { currentTemplate },
                            set: { newValue in
                                if let index = store.templates.firstIndex(where: { $0.id == template.id }) {
                                    store.templates[index] = newValue
                                }
                            }
                        ))
                        .environmentObject(store)
                    }
                    Spacer()
                    Button("Start Workout") {
                        let newSession = store.startSessionAndReturn(from: currentTemplate)
                        navigationPath.append(newSession)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(template.name)
    }

    private func groupedSets(for template: WorkoutTemplate) -> [Exercise: [WorkoutSet]] {
        Dictionary(grouping: template.sets, by: { $0.exercise })
    }
}






struct SessionView: View {
    @EnvironmentObject var store: WorkoutStore
    var template: WorkoutTemplate
    @Binding var navigationPath: NavigationPath // <- add this binding

    
    var body: some View {
        VStack {
            Button("Start Workout") {
                store.startSession(from: template)
            }
            List {
                ForEach(store.sessions.filter { $0.template.id == template.id }) { session in
                    NavigationLink("Session: \(session.startTime, style: .time)") {
                        WorkoutDetailView(navigationPath: $navigationPath, session: session, )
                            .environmentObject(store)

                    }
                }
            }
        }
        .navigationTitle(template.name)
    }
}

struct WorkoutDetailView: View {
    @EnvironmentObject var store: WorkoutStore
    @Environment(\.dismiss) var dismiss
    @Binding var navigationPath: NavigationPath
    var session: WorkoutSession
    
    var body: some View {
        VStack {
            Text(session.template.name)
                .font(.title2)
                .padding()
            
            List {
                ForEach(session.template.sets) { set in
                    HStack {
                        Text(set.exercise.name)
                        Spacer()
                        Text("\(set.weight, specifier: "%.1f") kg x \(set.reps)")
                    }
                }
            }
            
            Button("Finish Session") {
                if hasIncompleteSets(session) {
                    confirmFinishSession(session)
                } else {
                    completeSession(session)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .navigationTitle("Session")
    }
    
    private func hasIncompleteSets(_ session: WorkoutSession) -> Bool {
        // stub: replace with your own set completion logic
        return false
    }
    
    private func confirmFinishSession(_ session: WorkoutSession) {
        // Simplified inline confirmation for now
        if let index = store.sessions.firstIndex(where: { $0.id == session.id }) {
            store.finishSession(store.sessions[index])
            navigationPath.removeLast(navigationPath.count) // return to home
        }
    }
    
    private func completeSession(_ session: WorkoutSession) {
        if let index = store.sessions.firstIndex(where: { $0.id == session.id }) {
            store.finishSession(store.sessions[index])
            navigationPath.removeLast(navigationPath.count) // return to home
        }
    }
}


struct AddSetView: View {
    @EnvironmentObject var store: WorkoutStore
    @Binding var template: WorkoutTemplate
    @State private var selectedExercise: Exercise? = nil
    @State private var weight: Double = 0
    @State private var reps: Int = 0
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            // Exercise Picker
            Picker("Exercise", selection: $selectedExercise) {
                ForEach(store.exercises) { exercise in
                    Text(exercise.name).tag(Optional(exercise))
                }
            }

            // Weight Field
            HStack {
                Text("Weight (kg)")
                    .frame(width: 100, alignment: .leading)
                TextField("Enter weight", value: $weight, formatter: NumberFormatter())
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Reps Field
            HStack {
                Text("Reps")
                    .frame(width: 100, alignment: .leading)
                TextField("Enter reps", value: $reps, formatter: NumberFormatter())
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Add Button
            Button("Add") {
                guard let exercise = selectedExercise else { return }

                let newSet = WorkoutSet(exercise: exercise, weight: weight, reps: reps)
                store.addSet(to: template, set: newSet)

                if let index = store.templates.firstIndex(where: { $0.id == template.id }) {
                    template = store.templates[index]
                }

                dismiss()
            }
        }
        .navigationTitle("Add Set")
    }
}




// MARK: - Preview
#Preview {
    ContentView()
}
