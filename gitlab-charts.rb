#!/usr/bin/env ruby

require 'gitlab'
require 'date'
require 'gruff'

PROJECT_ID = ENV['GITLAB_API_PROJECT_ID']


def generate_datapoints(milestone)
  start_date = Date.parse(milestone.start_date)
  due_date = Date.parse(milestone.due_date)
  issues = []
  labels = {}
  data = {}

  Gitlab.milestone_issues(PROJECT_ID, milestone.id).each do |i|
    opened = Date.parse(i.created_at)

    if i.state == 'closed'
      closed = Date.parse(i.updated_at)
    else
      closed = nil
    end

    issues << { opened: opened, closed: closed }
  end

  today = 0
  days  = (due_date - start_date + 1).to_i
  days.times do |d|
    date = start_date + d
    labels[d] = "#{date.day}/#{date.month}" if d % 2 == 0

    today = d if date == Date.today

    if date <= Date.today
      open_issues = 0
      issues.each do |i|
        if date >= i[:opened]
          open_issues += 1
        end
        unless i[:closed].nil? || date <= i[:closed]
          open_issues -= 1
        end
      end

      data[d] = open_issues
    end
  end

  return { labels: labels, data: data, today: today }
end

options = {
  state: 'active'
}
Gitlab.milestones(PROJECT_ID, options).each do |milestone|
  datapoints = generate_datapoints(milestone)
  g = Gruff::Line.new

  g.title = milestone.title
  g.labels = datapoints[:labels]
  g.marker_font_size = 10
  g.line_width = 2
  g.dot_radius = 3
  g.hide_legend = true
  g.y_axis_increment = 2
  g.y_axis_label = 'Issues'
  g.x_axis_label = 'Dates'

  g.dataxy :target, [[0, datapoints[:data][0]], [datapoints[:labels].keys.last, 0]]
  #g.dataxy :today, [[datapoints[:today], 0], [datapoints[:today], datapoints[:data].values.max]] 
  g.dataxy :issues, datapoints[:data]

  g.write(milestone.id.to_s + '.png')
end
