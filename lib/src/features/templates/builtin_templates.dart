/// Dev2 sở hữu: 15 template việc nhà VN có sẵn.
/// Mỗi template: icon (emoji) + chu kỳ + mô tả 1 dòng.
/// Màn hình Form/Onboarding dùng list này để tạo nhanh Task.
class HabitTemplate {
  final String title;
  final String icon;
  final int cycleDays;
  final int remindBeforeDays;
  final String description;

  const HabitTemplate({
    required this.title,
    required this.icon,
    required this.cycleDays,
    this.remindBeforeDays = 2,
    required this.description,
  });
}

const List<HabitTemplate> builtinTemplates = <HabitTemplate>[
  HabitTemplate(
    title: 'Dọn toilet',
    icon: '🚽',
    cycleDays: 7,
    description: 'Cọ bồn cầu, lavabo và thay khăn lau mỗi tuần.',
  ),
  HabitTemplate(
    title: 'Giặt ga giường',
    icon: '🛏️',
    cycleDays: 14,
    description: 'Giặt ga, vỏ gối để tránh mạt bụi gây dị ứng.',
  ),
  HabitTemplate(
    title: 'Lau nhà',
    icon: '🧹',
    cycleDays: 3,
    description: 'Quét + lau sàn nhà, tập trung bếp và lối đi.',
  ),
  HabitTemplate(
    title: 'Giặt rèm cửa',
    icon: '👕',
    cycleDays: 90,
    description: 'Tháo rèm giặt khô/ướt, hút bụi thanh treo.',
  ),
  HabitTemplate(
    title: 'Tẩy lồng giặt',
    icon: '🧺',
    cycleDays: 30,
    description: 'Chạy chế độ vệ sinh lồng + giấm/bột chuyên dụng.',
  ),
  HabitTemplate(
    title: 'Vệ sinh máy lạnh',
    icon: '🌬️',
    cycleDays: 90,
    description: 'Rửa lưới lọc, kiểm tra gas và dàn lạnh.',
  ),
  HabitTemplate(
    title: 'Thay bàn chải',
    icon: '🪥',
    cycleDays: 90,
    description: 'Thay bàn chải mới để tránh vi khuẩn tích tụ.',
  ),
  HabitTemplate(
    title: 'Thay lõi lọc nước',
    icon: '💧',
    cycleDays: 180,
    remindBeforeDays: 7,
    description: 'Thay lõi theo khuyến cáo hãng để nước an toàn.',
  ),
  HabitTemplate(
    title: 'Cắt tóc',
    icon: '💇',
    cycleDays: 30,
    description: 'Cắt/tỉa tóc định kỳ cho gọn gàng.',
  ),
  HabitTemplate(
    title: 'Tẩy giun',
    icon: '💊',
    cycleDays: 180,
    remindBeforeDays: 7,
    description: 'Uống thuốc tẩy giun cho cả nhà 6 tháng/lần.',
  ),
  HabitTemplate(
    title: 'Khám răng',
    icon: '🦷',
    cycleDays: 180,
    remindBeforeDays: 7,
    description: 'Cạo vôi + khám tổng quát răng miệng.',
  ),
  HabitTemplate(
    title: 'Tưới cây',
    icon: '🌱',
    cycleDays: 2,
    remindBeforeDays: 1,
    description: 'Tưới sáng sớm, kiểm tra lá úa và sâu.',
  ),
  HabitTemplate(
    title: 'Dọn tủ lạnh',
    icon: '🧊',
    cycleDays: 7,
    description: 'Bỏ đồ hết hạn, lau kệ và khay rau.',
  ),
  HabitTemplate(
    title: 'Thay nhớt xe',
    icon: '🛵',
    cycleDays: 45,
    remindBeforeDays: 3,
    description: 'Thay nhớt + kiểm tra thắng, lốp, đèn.',
  ),
  HabitTemplate(
    title: 'Vệ sinh nệm',
    icon: '🛋️',
    cycleDays: 60,
    description: 'Hút bụi, phơi nắng và xoay đầu nệm.',
  ),
];
