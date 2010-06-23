# -*- coding: utf-8 -*-

miquire :mui, 'skin'
miquire :addon, 'addon'
miquire :addon, 'settings'

class Addon::Profile < Addon::Addon

  Tab = Class.new(Addon::Addon.gen_tabclass('のプロフィール', nil)){
    def initialize(name, service, options = {})
      @page = 1
      options[:header] = Gtk::VBox.new(false, 0)
      super(name, service, options) end

    def user
      @options[:user] end

    def on_create
      Thread.new{
        tl = @service.scan(:user_timeline, :user_id => user[:id],
                           :no_auto_since_id => true,
                           :count => 20)
        Delayer.new{ timeline.add(tl) } if tl }
      header.closeup(profile).show_all
      super
      focus end

    private

    def background_color
      style = Gtk::Style.new()
      style.set_bg(Gtk::STATE_NORMAL, 0xFF ** 2, 0xFF ** 2, 0xFF ** 2)
      style end

    def profile
      eventbox = Gtk::EventBox.new
      eventbox.signal_connect('visibility-notify-event'){
        eventbox.style = background_color
        false }
      eventbox.add(Gtk::VBox.new(false, 0).
                   closeup(toolbar).
                   add(Gtk::HBox.new(false, 16).
                       closeup(Gtk::WebIcon.new(user[:profile_image_url]).top).
                       add(Gtk::VBox.new(false, 0).add(main(eventbox))))) end

    def toolbar
      container = Gtk::HBox.new(false, 0)
      close = Gtk::Button.new('×')
      close.signal_connect('clicked'){ self.remove }
#       nextpage = Gtk::Button.new('+')
#       nextpage.signal_connect('clicked'){ self.next_page }
      container.closeup(close) # .closeup(nextpage)
    end

    def main(window_parent)
      ago = (Time.now - (user[:created] or 1)).to_i / (60 * 60 * 24)
      tags = []
      text = "#{user[:idname]} #{user[:name]}\n"
      append = lambda{ |title, value|
        tags << ['_caption_style', text.strsize, title.strsize]
        text << "#{title} #{value}" }
      append.call "location", "#{user[:location]}\n" if user[:location]
      append.call  "web", "#{user[:url]}\n" if user[:url]
      append.call "bio", "#{user[:detail]}\n\n" if user[:detail]
      append.call "フォロー", "#{user[:friends_count]} / "
      append.call "フォロワー", "#{user[:followers_count]} / #{user[:statuses_count]}Tweets " +
        "(#{(user[:statuses_count].to_f / ago).round_at(2) }/day)\n"
      append.call "since", "#{user[:created].strftime('%Y/%m/%d %H:%M:%S')}" if user[:created]
      body = Gtk::IntelligentTextview.new(text)
      body.buffer.create_tag('_caption_style',
                             'foreground_gdk' => Gdk::Color.new(0, 0x33 ** 2, 0x66 ** 2),
                             'weight' => Pango::FontDescription::WEIGHT_BOLD)
      tags << [tag_user_id_link(body), 0, user[:idname].size]
      tags.each{ |token|
        body.buffer.apply_tag(token[0], *body.buffer.get_range(*token[1..2])) }
      body.get_background = lambda{ background_color }
      body end

    private

    def tag_user_id_link(body)
      tag = body.buffer.create_tag('_user_id_link',
                                   'foreground' => 'blue',
                                   "underline" => Pango::UNDERLINE_SINGLE)
      tag.signal_connect('event'){ |this, textview, event, iter|
        result = false
        if(event.is_a?(Gdk::EventButton)) and
            (event.event_type == Gdk::Event::BUTTON_RELEASE) and
            not(textview.buffer.selection_bounds[2])
          if (event.button == 1)
            Gtk::IntelligentTextview.openurl('http://twitter.com/'+user[:idname]) end
        elsif(event.is_a?(Gdk::EventMotion))
          body.set_cursor(textview, Gdk::Cursor::HAND2) end
        result }
      tag end }

  include Addon::SettingUtils

  def onboot(service)
    @service = service
    Gtk::Mumble.contextmenu.registmenu(lambda{ |m, w|
                                         u = if(m.message[:retweet])
                                               m.message[:retweet].user
                                             else
                                               m.message.user end
                                         "#{u[:idname]}(#{u[:name]})について".gsub(/_/, '__') },
                                       lambda{ |m, w| m.message.repliable? }){ |m, w|
      user = if(m.message[:retweet]) then m.message[:retweet].user else m.message.user end
      makescreen(user) }
    Gtk::TimeLine.addlinkrule(/@[a-zA-Z0-9_]+/){ |match, *trash|
      user = User.findByIdname(match[1, match.length])
      if user
        makescreen(user)
      else
        Thread.new{
          user = @service.scan(:user_show,
                               :no_auto_since_id => false,
                               :screen_name => match[1, match.length])
          Delayer.new{ makescreen(user.first) } if user } end } end

  private

  def makescreen(user)
    if user[:exact]
      Tab.new("#{user[:idname]}(#{user[:name]})", @service,
              :user => user,
              :icon => user[:profile_image_url])
    else
      Thread.new{
        retr = @service.scan(:user_show, :screen_name => user[:idname],
                             :no_auto_since_id => true)
        Delayer.new{ makescreen(retr.first) } if retr }
    end end end

Plugin::Ring.push Addon::Profile.new,[:boot]
