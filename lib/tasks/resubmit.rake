namespace :redmine do
    namespace :resubmit do
    
          desc <<-END_DESC

Resubmit an issue by changing the status to the chosen status at the date set in the date field for resubmission

Configuration required in Administration->Plugins->Redmine Auto Resubmission plugin

Example:

rake redmine:resubmit:resubmit_issues RAILS_ENV="production"
END_DESC

      task :resubmit_issues, [:user_id] => :environment do |task, args|
        User.current = User.find(args[:user_id]) rescue User.current if args[:user_id]
        RedmineAutoResubmission.calc_all_resubmission_dates
      end
      
      task :test, [:user_id]  => :environment do  |task, args|
        
        puts "------------- testing date calculations and rules -------------"
        puts "--- parameters"
        puts "--- 1. epoch character (shall be one of the following)"
        puts "----- D - stands for _D_ays"
        puts "----- W - stands wor _W_eeks"
        puts "----- m - stands for _m_ondays"
        puts "----- M - stands for _M_onths"
        puts "----- q - stands for _q_uarters"
        puts "----- Y - stands for _Y_ears"
        puts "----- C - stands for European _C_alendar weeks (absolute, not relative)"
        puts ""
        puts "--- 2. count character (shall be integer)"
        puts "----- n - stands for number of epochs (first character)"
        puts ""
        puts "--- 3. (optional) position character - only for W, M, Y and q"
        puts "----- F - stands for _F_irst day in epoch"
        puts "----- M - stands wor _M_id day in epoch"
        puts "----- L - stands for _L_ast day in epoch - for (business) weeks this will be friday"
        puts "------W - stands for _W_orking day"
        puts "------X - stands for no correction"
        puts "----- - - is the kill switch - rule will be deleted after first calculation"
        puts ""
        puts "--- 4. (optional) kill switch"
        puts "----- - - is the kill switch - rule will be deleted after first calculation"
        puts "----- ! - is the force switch - rule will be applied, even for future start dates"
        puts "----- * - is the mock switch - do not calculate, remove mock switch from new rule"
        puts ""
        puts "example: W1F - means one week from now, first day, namely monday"
        puts "example: M3M - means three months from now, mid day, namely the 15th"
        puts "example: q1- - means one quarter from now, beginning of quarter month, namely the 1st Jan., Apr., Jul. or Oct."
        puts "               after one calculation rule is deleted"
        puts "example: D1- - tomorrow, then delete rule"
        puts ""
        puts "be careful:"
        puts "example: m0  - monday of current week - will not calculate date in the past"
        puts ""
        puts ""
        
        puts RedmineAutoResubmission.instance_methods
        
        puts ""
        puts ""
        puts "---------- example (real) calculations -------------"
        
        puts "tomorrow: D1"
        puts RedmineAutoResubmission.calcfuturedate( Date.today, "D1" ).to_s
        puts ""
        
        puts "next week: W1"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "W1" ).to_s
        puts ""
        
        puts "Monday: m0 "
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "m0" ).to_s
        puts ""
        
        puts "Wednesday W0M"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "W0M" ).to_s
        puts ""
        
        puts "Friday: W0L"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "W0L" ).to_s
        puts ""
        
        puts "next Monday: m1"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "m1" ).to_s
        puts ""
        
        puts "next Monday: W1F"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "W1F" ).to_s
        puts ""
        
        puts "next Wednesday: W1M"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "W1M" ).to_s
        puts ""
        
        puts "next Friday: W1L"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "W1L" ).to_s
        puts ""
        
        puts "next month: M1"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "M1" ).to_s
        puts ""
        
        puts "next month, first: M1F"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "M1F" ).to_s
        puts ""
        
        puts "next month, mid: M1M"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "M1M" ).to_s
        puts ""
        
        puts "next month, last: M1L"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "M1L" ).to_s
        puts ""
        
        puts "next quarter: q1"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "q1" ).to_s
        puts ""
        
        puts "next year: Y1"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "Y1" ).to_s
        puts ""
        
        puts "next year, beginning: Y1F"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "Y1F" ).to_s
        puts ""
        
        puts "next year, mid: Y1M"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "Y1M" ).to_s
        puts ""
        
        puts "next year, last: Y1L"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "Y1L" ).to_s
        puts ""
        
        puts "next calendar week 1 (European calendar weeks: CW '1' is the week containg Jan, 4th)"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "C1" ).to_s
        puts ""
        
        puts ""
        puts ""
        puts "---------- with killswitch -------------"
        
        puts "tomorrow: D1-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "D1-" ).to_s
        puts ""
        
        puts "next week: W1-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "W1-" ).to_s
        puts ""
        
        puts "Monday: m0-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "m0-" ).to_s
        puts ""
        
        puts "Wedenesday: W0M-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "W0M-" ).to_s
        puts ""
        
        puts "Friday: W0L-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "W0-L" ).to_s
        puts ""
        
        puts "next Monday: m1-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "m1-" ).to_s
        puts ""
        
        puts "next Monday: W1F-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "W1F-" ).to_s
        puts ""
        
        puts "next Wednesday: W1M-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "W1M-" ).to_s
        puts ""
        
        puts "next Friday: W1L-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "W1L-" ).to_s
        puts ""
        
        puts "next month: M1-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "M1-" ).to_s
        puts ""

        puts "next month, first: M1F-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "M1F-" ).to_s
        puts ""

        puts "next month, mid: M1M-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "M1M-" ).to_s
        puts ""
        
        puts "next month, last: M1L-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "M1L-" ).to_s
        puts ""
        
        puts "next quarter: q1-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "q1-" ).to_s
        puts ""
        
        puts "next year: Y1-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "Y1-" ).to_s
        puts ""
        
        puts "next year, beginning: Y1F-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "Y1F-" ).to_s
        puts ""
        
        puts "next year, mid: Y1M-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "Y1M-" ).to_s
        puts ""
        
        puts "next year, last: Y1L-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "Y1L-" ).to_s
        puts ""
        
        puts "next calendar week 1 (European calendar weeks: CW '1' is the week containg Jan, 4th)"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "C1" ).to_s
        puts ""
        
        puts ""
        puts ""
        puts "---------- with junk input -------------"
        
        puts "tomorrow: D-1-"
        puts RedmineAutoResubmission.calcfuturedate(  Date.today, "D-1-" ).to_s
        
      end
      
      
    end
end
