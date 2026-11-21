namespace ECommerce.Domain.Customers;

public sealed class Customer(int id, string name, string email, int partnerId, string province = "", string phone = "")
{
    public int Id { get; } = id;
    public string Name { get; } = name;
    public string Email { get; } = email;
    public int PartnerId { get; } = partnerId;
    public string Province { get; } = province;
    public string Phone { get; } = phone;
}

