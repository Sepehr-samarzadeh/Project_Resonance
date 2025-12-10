//
//  ContentView.swift
//  Resonance
//
//  Created by Sepehr on 19/11/2025.
//

import SwiftUI

struct ContentView: View {
    
    var body: some View {
        GeometryReader{geo in
            NavigationStack {
                ZStack {
                    //background
                    Image(.background)
                        .resizable()
                        .ignoresSafeArea()
                    
                    VStack(alignment: .center) {
                        //profilepic
                        //Image(.peopleVibe)
                        Image(.peopleVibe)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width*0.9, height: geo.size.height*0.4)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                          
                            
                        
                        Image(.crowdFestival)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width,height: geo.size.height*0.4)
                            .padding(-52)
                            .cornerRadius(10)
                            
                        NavigationLink {
                            Some()
                        } label: {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                
                                Text("Go to the Friends page")
                                    .font(.system(size: 18, weight: .bold, design: .default))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 10)
                                    .background(Color.brown)
                                    .cornerRadius(10)
                            }
                        }
                            }}
                        
                        
                    }
                    
                    
                }
                .preferredColorScheme(.dark)
            }
            
        }
    

        
        
        
        
    


#Preview {
    ContentView()
}
