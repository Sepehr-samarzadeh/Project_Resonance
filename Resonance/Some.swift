//
//  Some.swift
//  Resonance
//
//  Created by Sepehr on 09/12/2025.
//

import SwiftUI

struct Some: View {
    @State var searchText: String = ""
    var body: some View {
        NavigationStack {
            //list your things and then loop into them
            List {
                Text("friend 1")
                Text("friend 2")
                Text("firend 3")
            }
        }.searchable(text: $searchText)
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        //navigation stack
        //listview
        //each item is a friend
        //click on them fetch them
    }
}

#Preview {
    Some()
}
