//
//  AmountUsed.swift
//  AmountUsed
//
//  Created by Taehun Yang on 2022/11/12.
//

import WidgetKit
import SwiftUI
import Intents
import Alamofire
import SwiftSoup

// Widget 기본 설정
struct AmountUsed: Widget {
    let kind: String = "AmountUsed"
    
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: ConfigurationIntent.self,
            provider: Provider()
        ) { entry in
            AmountUsedEntryView(entry: entry)
        }
        .configurationDisplayName("실시간 사용량 조회")
        .description("tplus 실시간 사용량을 조회할 수 있습니다!")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// Widget Preview 구성
struct AmountUsed_Previews: PreviewProvider {
    static var previews: some View {
        let date = Date()
        let configuration = ConfigurationIntent()
        let usages = UsageEntry()
        let entry = AmountUsedEntry(date: date, configuration: configuration, usages: usages)
        
        AmountUsedEntryView(entry: entry)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}

/// Widget 렌더링에 필요한 Timeline 생성
struct Provider: IntentTimelineProvider {
    
    func placeholder(in context: Context) -> AmountUsedEntry {
        let date = Date()
        let configuration = ConfigurationIntent()
        let usages = UsageEntry()
        return AmountUsedEntry(date: date, configuration: configuration, usages: usages)
    }
    
    func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (AmountUsedEntry) -> ()) {
        let date = Date()
        let configuration = ConfigurationIntent()
        
        let entry: AmountUsedEntry
        let usages = UsageEntry()
        entry = AmountUsedEntry(date: date, configuration: configuration, usages: usages)
        completion(entry)
    }
    
    // 새로고침 주기를 정함
    func getTimeline(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [AmountUsedEntry] = []
        
        // 다음 업데이트 주기 설정
        let currentDate = Date()
        let nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        
        // 다음 업데이트 때 보여줄 엔트리 설정
        let configuration = ConfigurationIntent()
        
        // 업데이트 정보 생성
        getAmountUsed { result in
            let entry = AmountUsedEntry(
                date: currentDate,
                configuration: configuration,
                usages: result
            )
            entries.append(entry)
            
            // 다음 주기에 해당 엔트리를 수행할 것을 등록
            let timeline = Timeline(
                entries: entries,
                policy: .after(nextUpdateDate)
            )
            completion(timeline)
        }
    }
    
    /// [추가 함수] 현재 사용량 조회
    func getAmountUsed(completion: @escaping (UsageEntry) -> ()) {
        var usages = UsageEntry()
        
        let interactor = Interactor()
        let login:Bool = interactor.fetchAmountUsed { result in
            switch result.result {
            case .success(let data):
                usages = self.getAmountUsed(data: data)
                completion(usages)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        if (!login) {
            completion(UsageEntry())
        }
    }
    
    /// [추가 함수] 현재 사용량 조회  (Rough)
    func getAmountUsed(data:String) -> UsageEntry {
        do {
            let doc:Document = try SwiftSoup.parse(data)
            let divs:Elements = try doc.select("div")
            for div:Element in divs {
                if (div.hasClass("amountUsed")){
                    return try extractUsage(data: try div.select("div"))
                }
            }
        } catch Exception.Error(_, let message) {
            print(message)
        } catch {
            print("error")
        }
        return UsageEntry()
    }
    
    /// [추가 함수] 현재 사용량 조회 (Detail)
    func extractUsage(data:Elements) throws -> UsageEntry {
        var usages:UsageEntry = UsageEntry()
        for i in 1..<data.count {
            var usage:String = ""
            let div = data[i]
            let voice:Elements = try div.select("span")
            for rate:Element in voice {
                if (rate.hasClass("rate")){
                    usage = try rate.text().replacingOccurrences(of: " ", with: "")
                    break
                }
            }
            
            let values:[Substring] = usage.split(separator: "/")
            
            if (div.hasClass("voice")){
                usages.voice_tot = Double(values[1])!
                usages.voice_usage = Double(values[0])!
            }
            else if (div.hasClass("mms")){
                usages.mms_tot = Double(values[1])!
                usages.mms_usage = Double(values[0])!
            }
            else if (div.hasClass("data")){
                usages.data_tot = Double(values[1])! / 1024
                usages.data_usage = Double(values[0])! / 1024
            }
        }
        return usages
    }
}

struct AmountUsedEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationIntent
    var usages: UsageEntry
}

struct UsageEntry {
    var voice_tot:Double = 0
    var voice_usage:Double = 0
    var data_tot:Double = 0
    var data_usage:Double = 0
    var mms_tot:Double = 0
    var mms_usage:Double = 0
}

struct AmountUsedEntryView : View {
    @Environment(\.widgetFamily) private var widgetFamily
    
    var entry: Provider.Entry
    
    var body: some View {
        switch widgetFamily{
        case .systemSmall:
            amountUsedSmallView.environment(\.colorScheme, .light)
        case .systemMedium:
            amountUsedMediumView.environment(\.colorScheme, .light)
        default:
            Text("Unknown")
        }
    }
    
    let tplusMainColor = Color(red: 0xDA/255, green: 0x3B/255, blue: 0x75/255)
    let backgroundColor = Color(red: 247/255, green: 234/255, blue: 239/255)
    let categoryColor = Color(red: 221/255, green: 150/255, blue: 178/255)
    let progressBarColor = Color(red: 180/255, green: 150/255, blue: 178/255)
    
    let smallViewTextSize = 10.0
    let smallViewProgressTextSize = 10.0
    let smallViewFrontWeight = 0.35
    let smallViewRearWeight = 0.65
    var amountUsedSmallView: some View {
        GeometryReader { geometry in
            VStack{
                Text("실시간 사용량")
                    .foregroundColor(.white)
                    .font(Font.system(size: 15, weight: .bold, design: .rounded))
                    .padding([.top, .bottom, .horizontal], 5)
                    .frame(maxWidth: .infinity, idealHeight: .infinity)
                    .background(tplusMainColor)
                    .cornerRadius(16)
                VStack{
                    HStack(){
                        Text("음성\n(분)")
                            .foregroundColor(Color.white)
                            .font(Font.system(size: smallViewTextSize, weight: .bold, design: .rounded))
                            .frame(maxWidth: geometry.size.width * smallViewFrontWeight, maxHeight: .infinity)
                            .background(categoryColor)
                            .cornerRadius(16)
                            .lineLimit(2)
                        VStack{
                            ProgressView(value: entry.usages.voice_usage, total: entry.usages.voice_tot)
                                .progressViewStyle(LinearProgressViewStyle(tint: .red))
                                .background(progressBarColor)
                                .cornerRadius(5)
                            
                            Text(String(format: "%3.f/%.3.f",entry.usages.voice_usage,entry.usages.voice_tot))
                                .foregroundColor(Color.black)
                                .font(Font.system(size: smallViewProgressTextSize, weight: .regular, design: .rounded))
                                .cornerRadius(16)
                        }
                        .frame(maxWidth: geometry.size.width * smallViewRearWeight, maxHeight: .infinity)
                        .padding([.trailing], 5)
                    }
                    HStack(){
                        Text("문자\n(건)")
                            .foregroundColor(Color.white)
                            .font(Font.system(size: smallViewTextSize, weight: .bold, design: .rounded))
                            .frame(maxWidth: geometry.size.width * smallViewFrontWeight, maxHeight: .infinity)
                            .background(categoryColor)
                            .cornerRadius(16)
                            .lineLimit(2)
                        VStack{
                            ProgressView(value: entry.usages.mms_usage, total: entry.usages.mms_tot)
                                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                .background(progressBarColor)
                                .cornerRadius(5)
                            
                            Text(String(format: "%3.f/%.3.f",entry.usages.mms_usage,entry.usages.mms_tot))
                                .foregroundColor(Color.black)
                                .font(Font.system(size: smallViewProgressTextSize, weight: .regular, design: .rounded))
                                .cornerRadius(16)
                        }
                        .frame(maxWidth: geometry.size.width * smallViewRearWeight, maxHeight: .infinity)
                        .padding([.trailing], 5)
                    }
                    HStack(){
                        Text("데이터\n(GB)")
                            .foregroundColor(Color.white)
                            .font(Font.system(size: smallViewTextSize, weight: .bold, design: .rounded))
                            .frame(maxWidth: geometry.size.width * smallViewFrontWeight, maxHeight: .infinity)
                            .background(categoryColor)
                            .cornerRadius(16)
                            .lineLimit(2)
                        VStack{
                            ProgressView(value: entry.usages.data_usage, total: entry.usages.data_tot)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                .background(progressBarColor)
                                .cornerRadius(5)
                    
                            Text(String(format: "%3.2f/%.3.2f",entry.usages.data_usage,entry.usages.data_tot))
                                .foregroundColor(Color.black)
                                .font(Font.system(size: smallViewProgressTextSize, weight: .regular, design: .rounded))
                                .cornerRadius(16)
                        }
                        .frame(maxWidth: geometry.size.width * smallViewRearWeight, maxHeight: .infinity)
                        .padding([.trailing], 5)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(10)
            .background(backgroundColor)
        }
    }
    
    var amountUsedMediumView: some View {
        VStack{
            Text("실시간 사용량")
                .foregroundColor(.white)
                .font(Font.system(size: 15, weight: .bold, design: .rounded))
                .padding([.top, .bottom], 5)
                .frame(maxWidth: .infinity)
                .background(tplusMainColor)
                .cornerRadius(16)
            HStack{
                VStack{
                    Text("음성(분)")
                        .foregroundColor(Color.white)
                        .font(Font.system(size: 13, weight: .bold, design: .rounded))
                        .padding([.top, .bottom], 5)
                        .frame(maxWidth: .infinity)
                        .background(categoryColor)
                        .cornerRadius(16)
                    VStack{
                        ProgressView(value: entry.usages.voice_usage, total: entry.usages.voice_tot)
                            .progressViewStyle(LinearProgressViewStyle(tint: .red))
                            .background(progressBarColor)
                            .cornerRadius(5)
                        
                        Text(String(format: "%3.f/%.3.f",entry.usages.voice_usage,entry.usages.voice_tot))
                            .foregroundColor(Color.black)
                            .font(Font.system(size: 11, weight: .regular, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .cornerRadius(16)
                    }
                    .padding([.top], 5)
                    .padding([.horizontal], 10)
                }
                VStack{
                    Text("문자(건)")
                        .foregroundColor(Color.white)
                        .font(Font.system(size: 13, weight: .bold, design: .rounded))
                        .padding([.top, .bottom], 5)
                        .frame(maxWidth: .infinity)
                        .background(categoryColor)
                        .cornerRadius(16)
                    VStack{
                        ProgressView(value: entry.usages.mms_usage, total: entry.usages.mms_tot)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .background(progressBarColor)
                            .cornerRadius(5)
                        
                        Text(String(format: "%3.f/%.3.f",entry.usages.mms_usage,entry.usages.mms_tot))
                            .foregroundColor(Color.black)
                            .font(Font.system(size: 11, weight: .regular, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .cornerRadius(16)
                    }
                    .padding([.top], 5)
                    .padding([.horizontal], 10)
                }
                VStack{
                    Text("데이터(GB)")
                        .foregroundColor(Color.white)
                        .font(Font.system(size: 13, weight: .bold, design: .rounded))
                        .padding([.top, .bottom], 5)
                        .frame(maxWidth: .infinity)
                        .background(categoryColor)
                        .cornerRadius(16)
                    VStack{
                        ProgressView(value: entry.usages.data_usage, total: entry.usages.data_tot)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .background(progressBarColor)
                            .cornerRadius(5)
                        
                        Text(String(format: "%3.2f/%.3.2f",entry.usages.data_usage,entry.usages.data_tot))
                            .foregroundColor(Color.black)
                            .font(Font.system(size: 11, weight: .regular, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .cornerRadius(16)
                    }
                    .padding([.top], 5)
                    .padding([.horizontal], 10)
                }
            }
            Text(entry.date, style: .time)
                .foregroundColor(tplusMainColor)
                .font(Font.system(size: 13, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .background(Color.clear)
                .padding([.top, .bottom], 5)
                .cornerRadius(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
        .background(backgroundColor)
    }
}

class Interactor {
    let loginURL = "https://www.tplusmobile.com/view/mytplus/loginAction.do"
    let myPageURL = "https://www.tplusmobile.com/view/mytplus/getPrductrecomend.do"
    
    func fetchAmountUsed(completion: @escaping (AFDataResponse<String>) -> ()) -> Bool {
        let appGroupId = "group.github.tools.TplusMobile"
        let userDefaults = UserDefaults.init(suiteName: appGroupId)!
        
        let loginResult:Bool = userDefaults.value(forKey: "loginStatus") as! Bool
        if (!loginResult) {
            return loginResult
        }
        
        // 로그인 정보 파라미터 생성
        let id:String = userDefaults.value(forKey: "mberId") as! String
        let password:String = userDefaults.value(forKey: "password") as! String
        let parameters = [
            "mberId": id as String,
            "password": password as String
        ]
        
        let session = Session.default
        // 로그인 페이지
        session.request(loginURL, method: .get, parameters: parameters).responseString { result in
            switch result.result {
            case .success(_):
                // 로그인 성공 시 마이페이지
                print(result)
                session.request(self.myPageURL).responseString { result in
                    switch result.result {
                    case .success(_):
                        completion(result)
                    case .failure(let error):
                        print(error.localizedDescription)
                    }
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
        
        return loginResult
    }
}
