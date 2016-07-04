#!/usr/bin/ruby

require 'mechanize'
require 'highline/import'
require 'yaml'
require 'mailfactory'
require 'net/smtp'

home = ENV['HOME']

filename = home + '/.packt_checker.yml'

user_hash = {}

if File.file? filename
  user_hash = YAML.load_file(filename)
else
  if user_hash.empty?
    user_hash[:email] = ask("Enter your Packt email:  ") { |q| q.echo = true }
    user_hash[:password] = ask("Enter your password:  ") { |q| q.echo = "*" }
    save = HighLine.agree("Save user details to '#{filename}'?")
    if save
      puts "OK. Saving to '#{filename}'"
      File.open(filename, "w") do |file|
        file.write user_hash.to_yaml
      end
    else
      puts "OK. Not saving. You will be required to put your details again next time."
    end 
  end
end

class PacktUserLogin
  attr_accessor :email, :password, :smtp_password

  def initialize(user_hash)
    @email = user_hash[:email]
    @password = user_hash[:password]
    @smtp_password = user_hash[:smtp_password]
  end

  def login(m_agent, url = 'https://www.packtpub.com')
    m_agent.get(url) do |p|
      logged_in_page = p.form_with(id: 'packt-user-login-form') do |form|
        form.email = @email
        form.password = @password
      end.click_button
      logged_in_page
    end
  end
end

class PacktBook
  attr_accessor :title
   
  def initialize(title)
    @title = title
  end

  def eql?(other_book)
    @title == other_book.title
  end

  def hash
    @title.hash
  end

  def ==(other_book)
    @title == other_book.title
  end

end

module WebBooks
  def self.list(login)
    books = []
    m_agent = Mechanize.new
    logged_in_page = login.login(m_agent) 
    account_page = m_agent.click(logged_in_page.link_with(text: /My Account/))
    ebooks_page = m_agent.click(account_page.link_with(text: /My eBooks/))
    ebooks_page.search(".title").each do |title|
      books << PacktBook.new(title.text.sub('[eBook]', '').strip)
    end
    books
  end

  def self.free_book
    m_agent = Mechanize.new
    m_agent.get('https://www.packtpub.com/packt/offers/free-learning') do |p|
      title = p.search('.dotd-title h2')[0].text.strip
      return PacktBook.new(title)
    end
  end

  def self.click_free_book(login)
    m_agent = Mechanize.new
    logged_in_page = login.login(m_agent, 'https://www.packtpub.com/packt/offers/free-learning')
    m_agent.click(logged_in_page.link_with(href: /freelearning/))
  end
end

module PacktMail

  def self.send_mail(user, new_book)
    mail = MailFactory.new()
    mail.to = user.email
    mail.from = "localhost"
    mail.subject = "New Packt Book: #{new_book.title}"
    mail.text = "Congratulation! You have a new Packt Book in your library: #{new_book.title}"
    begin
      fromaddress = 'localhost'
      toaddress = user.email
      smtp = Net::SMTP.new('smtp.gmail.com', 587)
      smtp.enable_starttls
      smtp.start('gmail.com', user.email, user.smtp_password, :login) { |smtp|
        mail.to = toaddress
        smtp.send_message(mail.to_s(), fromaddress, toaddress)
      }
    rescue Errno::ECONNREFUSED
      puts 'Unable to send message. No SMTP Server. Skipping'
    end
  end
end

u = PacktUserLogin.new(user_hash)
books = WebBooks.list(u)

free_book = WebBooks.free_book

if books.include? free_book
  puts "You already own the Deal of the Day: '#{free_book.title}'"
else
  puts "New Book: #{free_book.title}!"
  WebBooks.click_free_book(u)
  PacktMail.send_mail(u, free_book)
end
