# encoding: utf-8
#
# Redmine plugin for provides a resubmission tool for issues
#
# Copyright © 2018 Stephan Wenzel <stephan.wenzel@drwpatent.de>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

module RedmineAutoResubmission 

  def self.calc_all_resubmission_dates
  
    new_status_id             = Setting['plugin_redmine_auto_resubmission']['issue_status_id'].presence
    custom_field_id_date      = Setting['plugin_redmine_auto_resubmission']['custom_field_id_date']
    issue_resubmission_notice = Setting['plugin_redmine_auto_resubmission']['resubmission_notice'].to_s
    
    issues                    = []
    new_notice                = issue_resubmission_notice.gsub(/##/, User.current.name )
    
    if custom_field_id_date.present?
    
      # search issues having a concrete resubmission date
      # careful: CAST(custom_values.value as DATE) <= NOW()
      # may fail, because sql is not good in error catching
      issues = Issue.
        joins(:custom_values).
        where("custom_values.custom_field_id = ?", custom_field_id_date).
        where("custom_values.value NOT LIKE ''").
        where("custom_values.value IS NOT NULL").
        where("CAST(custom_values.value as DATE) <= NOW()").
        distinct.
        to_a
          
      issues.each do |issue|
      
        # mark issue with resubmission notice
        new_journal = issue.init_journal( User.current, new_notice )
        new_journal.save # save journal triggers update_at field of parent issue

        Rails.logger.info "foo"
        
        # update issue status without triggering call_backs
        issue.update_columns({:status_id => new_status_id, :updated_on => Time.now}.compact)
        
      end #each
      
    end # if
    
    issues.length
    
  end #def
  
  
  # ----------------------------------------------------------------------------------- #
  def self.parse_rule(rule)
  
    m = {}
    matches = /(?<epoch>[DWMYCmq])(?<num>[0-9]+)(?<pos>[XFMLW]?)(?<kfm>[-!\*]*)(?<trailing_rest>.*)/.match(rule)
    
    if matches.present?
      m.merge!(Hash[ matches.names.zip( matches.captures ) ])
      m.merge!('killswitch' => m['kfm'].match(/-/).to_s)
      m.merge!('force'      => m['kfm'].match(/!/).to_s)
      m.merge!('mockswitch' => m['kfm'].match(/\*/).to_s)
    end
    m
  end #def
  
  
  # ----------------------------------------------------------------------------------- #
  def self.calcfuturedate( obj, rule )
    
    date = case obj.class.name
      when "Date", "DateTime"
        obj
      when "String"
        obj.to_date rescue nil
      else
        obj.respond_to?(:date) ? obj.date : nil
    end
    
    new_date = date
    new_rule = rule
    
    if rule.present?
    
      m = parse_rule( rule )
      
      if m['mockswitch'].present?
      
        # mockswitch does not calculate anything
        # mockswitch is removed from new_rule, however
        new_rule = unmock( rule, m )
        
      elsif date.blank? || date <= Date.today || m['force'].present?
      
        if( m['epoch'].present? && m['num'].present? )
        
          startdate = date.presence || Date.today
          new_date  = advance_date( startdate, m['epoch'], m['num'] ) 
          new_date  = adjust_date(  new_date,  m['epoch'], m['pos'] ) 
          new_date  = (new_date > startdate ? new_date : nil )
          new_rule  = "" if m['killswitch'].present?
          
        end #if
      end #if
    end #if
    
    [new_date, new_rule]
    
  end #def

  # ----------------------------------------------------------------------------------- #
  def self.unmock( rule, m=nil )
    m = parse_rule( rule ) unless m
    if m['mockswitch'].present?
      "#{m['epoch']}#{m['num']}#{m['pos']}#{m['killswitch']}#{m['force']}#{m['trailing_rest']}"
    else
      nil
    end
  end #def
  # ----------------------------------------------------------------------------------- #
  # calculate n times advance of epoch
  # epoch: D - n days
  # epoch: W - n weeks
  # epoch: M - n months
  # epoch: Y - n years
  #
  # epoch: C - n calendar weeks (absolute, not relative)
  # epoch: m - n mondays
  # epoch: q - q quarters
  
  def self.advance_date( startdate, epoch, num )
  
    today = User.current.today
          
    case epoch  
      when "D"
          new_date = startdate.advance( :days => num.to_i)        
      when "W"
          new_date = startdate.advance( :weeks => num.to_i)
      when "M"
          new_date = startdate.advance( :months => num.to_i)
      when "Y"
          new_date = startdate.advance( :years => num.to_i)
      when "m"
          new_date = startdate.advance( :weeks => num.to_i).monday 
          #new_date = startdate.advance( :weeks => (num.to_i+1)).monday if new_date <= today 
      when "q"
          new_date = startdate.advance( :months => 3 * num.to_i).beginning_of_quarter
          #new_date = startdate.advance( :months => 3 * (num.to_i+1)).beginning_of_quarter if new_date <= today 
      when "C"
          # calendar week 1 is the week containing Jan. 4th
          new_date = DateTime.new(startdate.year, 1, 4).advance( :weeks => (num.to_i - 1))
          #new_date = DateTime.new(startdate.year+1, 1, 4).advance( :weeks => (num.to_i - 1)) if new_date <= today
      else
          new_date = startdate
    end #case
    
    new_date 
    
  end #def

  # ----------------------------------------------------------------------------------- #
  # calculate time adjustment of epoch (_F_irst, _M_id, _L_ast, _W_orking day)
  # epoch: W - week:  F - Monday, M - Wednesday, L - Friday, W - Monday
  # epoch: M - month: F - 1st,    M - 15th,      L - last, W - Monday
  # epoch: Y - year:  F - 01/01,  M - 06/30,     L - 12/31, W - Monday
  # epoch: q - quarter:  W - Monday

  def self.adjust_date( startdate, epoch, pos )
  
    today = User.current.today

    case epoch
      when "D"
        case pos
          when "W"
          # if saturday or sunday, fall back to last monday, then add one week for monday coming up
            (startdate.wday % 6) != 0 ? new_date = startdate : new_date = startdate.monday.advance(:days => 7)
          else
            new_date = startdate
        end #case

      when "W", "C"
        # week
        case pos
          when "F"
            # Monday
            new_date = startdate.monday
            new_date = startdate.advance( :weeks => 1).monday if new_date <= today

          when "M"
            # Wednesday = Monday + 2 days
            new_date = startdate.monday.advance(:days => 2)
            new_date = startdate.advance( :weeks => 1).monday.advance(:days => 2) if new_date <= today
          when "L"
            # Friday = Monday + 4 days
            new_date = startdate.monday.advance(:days => 4)
            new_date = startdate.advance( :weeks => 1).monday.advance(:days => 4) if new_date <= today
          when "W"
          # if saturday or sunday, fall back to last monday, then add one week for monday coming up
            (startdate.wday % 6) != 0 ? new_date = startdate : new_date = startdate.monday.advance(:days => 7)
          else
            new_date = startdate
        end #case
      
      when "M"
        # month
        case pos
          when "F"
            # 1st
            new_date = startdate.beginning_of_month
            new_date = startdate.advance( :months => 1).beginning_of_month if new_date <= today
          when "M"
            # 15th 
            new_date = startdate.beginning_of_month.advance(:days => 14)
            new_date = startdate.advance( :months => 1).beginning_of_month.advance(:days => 14) if new_date <= today
          when "L"
            # last day
            new_date = startdate.end_of_month
            #new_date = startdate.advance( :months => 1).end_of_month if new_date <= today
          when "W"
          # if saturday or sunday, fall back to last monday, then add one week for monday coming up
            (startdate.wday % 6) != 0 ? new_date = startdate : new_date = startdate.monday.advance(:days => 7)
          else
            new_date = startdate
        end #case
       
      when "Y"
        # year
        case pos
          when "F"
            # Jan. 1st
            new_date = startdate.beginning_of_year
            new_date = startdate.advanve(:years => 1).beginning_of_year if new_date <= today
          when "M"
            # Jun. 30th 
            new_date = startdate.
                        beginning_of_year.
                        advance(:months => 5).
                        advance(:days => 29)
            new_date = startdate.
                        advance(:years => 1).
                        beginning_of_year.
                        advance(:months => 5).
                        advance(:days => 29) if new_date <= today
          when "L"
            # Dec. 31st
            new_date = startdate.
                        beginning_of_year.
                        advance(:months => 11).
                        advance(:days => 30)
          when "W"
          # if saturday or sunday, fall back to last monday, then add one week for monday coming up
            (startdate.wday % 6) != 0 ? new_date = startdate : new_date = startdate.monday.advance(:days => 7)
          else
            new_date = startdate
        end #case

      when "q"
        case pos
          when "F"
            # Jan. 1st
            new_date = startdate.beginning_of_quarter
            new_date = startdate.advance( :months => 3).beginning_of_quarter if new_date <= today 
          when "M"
            # Jun. 30th 
            new_date = startdate.
                        beginning_of_quarter.
                        advance(:months => 1).
                        advance(:days => 15)
            new_date = startdate.
                        advance(:quarters => 1).
                        beginning_of_quarter.
                        advance(:months => 1).
                        advance(:days => 15) if new_date <= today
          when "L"
            # Dec. 31st
            new_date = startdate.end_of_quarter
          when "W"
          # if saturday or sunday, fall back to last monday, then add one week for monday coming up
            (startdate.wday % 6) != 0 ? new_date = startdate : new_date = startdate.monday.advance(:days => 7)
          else
            new_date = startdate
        end #case
        
      else
        new_date = startdate
    end #case epoch
    
    new_date > today ? new_date : startdate
    
  end #def  


  
  # ----------------------------------------------------------------------------------- #
end #class
